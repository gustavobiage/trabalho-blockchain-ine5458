// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

abstract contract Roulette {
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
     * Registra a execução de fim de contrato
     */
    bool endedAlreadyExecuted;

    /**
     * Construtor;
     * @param c Refere-se ao número de cores na roleta (2^c).
     * @param token_ Define o preço de cada ficha apostada
     * @param tax_ Define a taxa de cada aposta que gera lucro para o proprietário do contrato.
     * @param duration Duração que o contrato se encontra aberto para apostas
     */
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
        }
        /**
         * A blockchain da etherium publica, em média, um bloco acada 15
         * segundos. Portanto, o tempo será contado por número de blocos.
         */
        // Expected number of block after this duration
        uint numberOfBlocks = duration / 15000000 + 1; // divisão de inteiro
        validUntil = block.number + numberOfBlocks;
        endedAlreadyExecuted = false;
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
        assert(!endedAlreadyExecuted);
        assert(hasEnded());
        uint selected = selectColor();

        // Distribui a premiação aos ganhadores
        uint prize = totalPrize;
        for (uint i = 0; i < colors[selected].bettors.length; i++) {
            address addr = colors[selected].bettors[i];
            uint bet = bets[addr].value;
            uint toTransfer = (prize * bet) / colors[selected].total;
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
        assert(!hasEnded())
        totalPrize += msg.value;
        totalDonation += msg.value;
    }

    function bettedOnColor(uint colorId) external view returns(uint){
        assert(colorId < nColors);
        return colors[colorId].total;
    }
}
