// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

abstract contract Roulette {
    /**
     * Unidade de tempo para duração do contrato
     */
    enum TimeUnit {MILLISECONDS}
    /**
     * Representa um par de aposta. Contendo
     * a cor apostada e o valor apostado.
     * value é o total de tokens comprados
     */
    struct Bet {
        uint color;
        uint value;
        bool registered;
    }
    /**
     * Estrutura que contém os dados necessários
     * para uma cor na roleta
     * total é o total de tokens comprados
     */
    struct Color {
        uint total;
        address payable[] bettors;
    }
    /**
     * Lista de cores na roleta
     */
    Color[] internal colors;
    /**
     * Mapa de apostas. Mapeia do endereço da
     * carteira que realizou a aposta para o valor
     * apostado.
     */
    mapping(address => Bet) public bets;
    /**
     * Número de cores
     */
    uint public nColors; 
    /**
     * Dono do contrato
     */
    address payable internal owner;
    /**
     * Total de doação para a roleta e o resto das apostas.
     */
    uint public totalDonation;
    /**
     * Total de dinheiro apostado.
     */
    uint public totalPrize;
    /**
     * Soma de todas as taxas;
     */
    uint public totalTax;
    /**
     * Preço de cada ficha (Todas as apostas devem ser
     * valores múltiplos deste.
     */
    uint public token;
    /**
     * Taxa enviada ao dono do contrado em cada aposta
     */
    uint public tax;
    /**
     * Referência final de bloco
     */
    uint public validUntil;

    /**
     * Construtor;
     * @param c Refere-se ao número de cores na roleta (2^c).
     * @param token_ Define o preço de cada ficha apostada
     * @param tax_ Define a taxa de cada aposta que gera lucro para o proprietário do contrato.
     * @param duration Duração que o contrato se encontra aberto para apostas
     */
    // constructor(uint c, uint token_, uint tax_, uint duration, TimeUnit timeUnit) payable {
    constructor(uint c, uint token_, uint tax_, uint duration) payable {
        owner = payable(msg.sender);
        nColors = (1 << c);
        totalDonation = msg.value;
        totalPrize = msg.value;
        token = token_;
        tax = tax_;
        for( uint i = 0; i < nColors; i++){
            address payable[] memory bettors;
            Color memory color = Color(0, bettors); 
            colors.push(color);
            // colors.push(Color({total: 0, bettors: address payable []}));
        }
        /**
         * A blockchain da etherium publica, em média, um bloco acada 15
         * segundos. Portanto, o tempo será contado por número de blocos.
         */
        // Expected number of block after this duration
        uint numberOfBlocks = duration / 15000000 + 1; // divisão de inteiro
        validUntil = block.number + numberOfBlocks;
    }

    function makeBet(uint color) external payable {
        // Verifica se o contrato ainda é válido
        assert(block.number <= validUntil);
        // Verifica que o valor transferido compra pelo menos uma ficha.
        assert(msg.value >= token + tax);
        // Verifica que este endereço não tem um aposta feita em uma outra cor.
        assert((bets[msg.sender].registered && bets[msg.sender].color == color) || !bets[msg.sender].registered);
        // Retira a taxa e compra as fichas.
        totalTax += tax;
        uint quotient = (msg.value - tax) / token; // divisão de inteiro
        uint remainder = (msg.value - tax) % token;
        // Realiza a compra das fichas
        bets[msg.sender].value += quotient;
        colors[color].total += quotient;
        // Adiciona o que sobrar nas doações
        totalDonation += remainder;
        // Adiciona o valor ao prêmio final
        totalPrize += msg.value - tax;

        // Registra um novo apostador a cor
        if (!bets[msg.sender].registered) {
            // Define a cor apostada deste endereço
            bets[msg.sender].color = color;
            // Registra a ocorrência de uma aposta por este endereço.
            bets[msg.sender].registered = true;   
            // Insere o endereço na lista de apostadores desta cor
            colors[color].bettors.push(payable(msg.sender));
        }
        // Termina o contrato caso o número máximo de blocos tenha passado
    }

    function endContract() public {
        assert(hasEnded());
        uint selected = selectColor();

        // Distribui a premiação aos ganhadores
        for (uint i = 0; i < colors[selected].bettors.length; i++) {
            address addr = colors[selected].bettors[i];
            uint bet = bets[addr].value;
            uint toTransfer = (totalPrize * (bet * token)) / (colors[selected].total * token);
            payable(addr).transfer(toTransfer);
            totalPrize -= toTransfer;
        }
        /*
         * Se sobrar alguma porcentagem que não conseguiu
         * ser distribuída igualmente, envia para o dono do contrato.
         */
        if (totalPrize > 0) {
            totalTax += totalPrize;
        }
        // Envia a parte do dono do contrato
        owner.transfer(totalTax);
    }

    function selectColor() internal virtual returns(uint);

    function hasEnded() public virtual returns(bool);

    function donate() external payable {
        totalPrize += msg.value;
        totalDonation += msg.value;
    }

    function bettedOnColor(uint colorId) external view returns(uint){
        assert(colorId < nColors);
        return colors[colorId].total;
    }
}

// 0. Jogo da roleta
// 1. submetem hashes de valores aleatórios (adiciona depósito)
// 2. submete o valore aleatórios e é verificado pelo hash (gera o valor final)
// 3. pega o depósito de volta.
contract RouletteColaborativeGeneration is Roulette {
    /**
     * Validade da primeira fase.
     */
    uint private hashValidUntil;
    /**
     * Validade da segunda fase.
     */
    uint private valueValidUntil;
     /**
      * Validade da terceira fase
      */
    uint private cashbackValidUntil;
    /**
     * Estrutura que armazena dados de submissão de um endereço
     */
    struct Submission {
        bool submittedHash;
        bytes32 hash;
        bool submittedValue;
        bool cashedBack;
    }
    /**
     * Mapa que relaciona um endereço aos seus dados de submissão
     */
    mapping(address => Submission) private submissionMap;

    /**
     * Highest possible submission
     */
    uint highestValue;
    
    /**
     * Valor total depositado
     */
    uint totalDeposit;
    
    /**
     * Total de valores submetidoes
     */
    uint valuesSubmitted;

    /**
     * Valor gerado até o momento;
     */
    uint generated;

    /**
     * Construtor;
     * @param c Refere-se ao número de cores na roleta (2^c).
     * @param token_ Define o preço de cada ficha apostada
     * @param tax_ Define a taxa de cada aposta que gera lucro para o proprietário do contrato.
     * @param gameDuration Duração que o contrato se encontra aberto para apostas
     * @param hashDuration Duração da fase de submissões de hash
     * @param valueDuration Duração da fase de submissões de valores
     * @param cachebackDuration Duração da fase de cacheback dos depósitos
     * @param highestValue_ maior valor que pode ser gerado aleatoriamente
     */
    // constructor(uint c, uint token_, uint tax_,
    //     uint gameDuration,
    //     uint hashDuration,
    //     uint valueDuration,
    //     uint cachebackDuration,
    //     TimeUnit timeUnit,
    //     uint highestValue_) payable Roulette(c, token_, tax_, gameDuration, timeUnit) {
    constructor(uint c, uint token_, uint tax_,
        uint gameDuration,
        uint hashDuration,
        uint valueDuration,
        uint cachebackDuration,
        uint highestValue_) payable Roulette(c, token_, tax_, gameDuration) {
        /*
         * Se cada duração possuir uma unidade de tempo diferente,
         * pela quantidade de variáveis, ocorre o erro de compilação:
         * 
         *     CompilerError: Stack too deep when compiling inline assembly:
         *     Variable headStart is 1 slot(s) too deep inside the stack.
         */
        // assert(timeUnit == TimeUnit.MILLISECONDS);
        assert(hashDuration > 15000000);
        assert(valueDuration > 15000000);
        assert(cachebackDuration > 15000000);

        uint hashNumberOfBlocks = hashDuration / 15000000 + 1;
        hashValidUntil = validUntil + hashNumberOfBlocks;
        uint valueNumberOfBlocks = valueDuration / 15000000 + 1;
        valueValidUntil =  hashValidUntil + valueNumberOfBlocks;
        uint cachebackNumberOfBlocks = cachebackDuration / 15000000 + 1;
        cashbackValidUntil = valueValidUntil + cachebackNumberOfBlocks;

        highestValue = highestValue_;
        totalDeposit = 0;
        valuesSubmitted = 0;
        generated = 0;
    }

    function submmitHash(bytes32 hash) external payable {
        assert(block.number > validUntil); // O jogo já terminou
        assert(block.number <= hashValidUntil); // O período de envio de hash ainda não terminou
        assert(msg.value >= highestValue); // O depósito é maior ou igual ao maior valor possível
        assert(!submissionMap[msg.sender].submittedHash); // Este endereço ainda não enviou um hash
        
        submissionMap[msg.sender].submittedHash = true; // Registra a submissão do hash
        submissionMap[msg.sender].hash = hash; // Armazena o hash submetido
        totalDeposit += msg.value; // Adiciona o valor de depósito a soma total
    }

    function submmitValue(uint value) external payable {
        assert(block.number > hashValidUntil); // Já terminou a fase de submeter hashes
        assert(block.number <= valueValidUntil); // Ainda não terminou a fase de submeter valores
        assert(value <= highestValue); // O valor está no intervalo exigido
        assert(submissionMap[msg.sender].submittedHash); // Este endereço enviou um hash
        assert(!submissionMap[msg.sender].submittedValue); // Este endereço ainda não enviou um valor
        
        bytes32 hash = keccak256(abi.encodePacked(msg.sender, value)); // Obtém o hash do valor e o endereço
        if (hash == submissionMap[msg.sender].hash) { // Compara com o hash submetido
            valuesSubmitted += 1; // Incrementa o número de valores submetidos
            generated = generated ^ value; // Computa o novo valor gerado
            submissionMap[msg.sender].submittedValue = true; // Registra a submissão deste endereço
        }
    }

    function cashbackDeposit() external {
        assert(block.number > valueValidUntil); // Já terminou a fase de submissão de valores
        assert(block.number <= cashbackValidUntil); // Ainda está na fase de retirar depósitos
        assert(submissionMap[msg.sender].submittedValue); // O endereço submeteu um valor
        assert(!submissionMap[msg.sender].cashedBack); // O endereço ainda não retirou o depósito

        uint cashback = totalDeposit / valuesSubmitted; // Divide os depósitos com todo mundo que submeteu
        payable(msg.sender).transfer(cashback); // Transfere a parte pertencente a este endereço
        submissionMap[msg.sender].cashedBack = true; // Registra a retirada de depósito
    }

    function selectColor() internal view override returns(uint) {
        return generated % nColors;
    }

    function hasEnded() public view override returns(bool) {
        return block.number > valueValidUntil;
    }
}


contract RouletteCompetitiveGeneration is Roulette {

    /**
     * Construtor;
     * @param c Refere-se ao número de cores na roleta (2^c).
     * @param token_ Define o preço de cada ficha apostada
     * @param tax_ Define a taxa de cada aposta que gera lucro para o proprietário do contrato.
     * @param gameDuration Duração que o contrato se encontra aberto para apostas
     */
    constructor(uint c, uint token_, uint tax_, uint gameDuration) payable Roulette(c, token_, tax_, gameDuration) {
    }

    function selectColor() internal view override returns(uint) {
        uint sum = 0;
        for (uint i = 0; i < nColors; i++) {
            sum += colors[i].total;
        }
        bytes32 hash = keccak256(abi.encodePacked(sum));
        uint mask = nColors - 1;
        return uint(hash) & mask;
    }

    function hasEnded() public view override returns(bool) {
        return block.number > validUntil;
    }
}
