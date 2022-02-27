// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./Roulette.sol";

/*
 * Fase 0: Jogo da roleta
 * Fase 1: participantes submetem hashes de valores aleatórios (adiciona depósito)
 * Fase 2: participantes submetem o valore aleatórios e é verificado pelo hash
 * Fase 3: participantes pegam o depósito de volta.
 */
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
