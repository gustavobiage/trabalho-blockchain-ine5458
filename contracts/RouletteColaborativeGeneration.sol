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
    uint public hashValidUntil;
    /**
     * Validade da segunda fase.
     */
    uint public valueValidUntil;
     /**
      * Validade da terceira fase
      */
    uint public cashbackValidUntil;
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
    mapping(address => Submission) public submissionMap;

    /**
     * Highest possible submission
     */
    uint public highestValue;
    
    /**
     * Valor total depositado
     */
    uint public totalDeposit;
    
    /**
     * Total de valores submetidoes
     */
    uint public valuesSubmitted;

    /**
     * Valor gerado até o momento;
     */
    uint public generated;
    

    /**
     * Construtor;
     * @param c Refere-se ao número de cores na roleta (2^c).
     * @param token_ Define o preço de cada ficha apostada
     * @param tax_ Define a taxa de cada aposta que gera lucro para o proprietário do contrato.
     * @param gameDuration Duração que o contrato se encontra aberto para apostas
     * @param hashDuration Duração da fase de submissões de hash
     * @param valueDuration Duração da fase de submissões de valores
     * @param cashbackDuration Duração da fase de cashback dos depósitos
     * @param highestValue_ maior valor que pode ser gerado aleatoriamente
     */
    constructor(uint c, uint token_, uint tax_,
        uint gameDuration,
        uint hashDuration,
        uint valueDuration,
        uint cashbackDuration,
        uint highestValue_) payable Roulette(c, token_, tax_, gameDuration) {

        require(hashDuration > 15000000, "Periodo (hashDuration) menor que 15 segundos.");
        require(valueDuration > 15000000, "Periodo (valueDuration) menor que 15 segundos.");
        require(cashbackDuration > 15000000, "Periodo (cashbackDuration) menor que 15 segundos.");

        uint hashNumberOfBlocks = hashDuration / 15000000 + 1;
        hashValidUntil = validUntil + hashNumberOfBlocks;
        uint valueNumberOfBlocks = valueDuration / 15000000 + 1;
        valueValidUntil =  hashValidUntil + valueNumberOfBlocks;
        uint cashbackNumberOfBlocks = cashbackDuration / 15000000 + 1;
        cashbackValidUntil = valueValidUntil + cashbackNumberOfBlocks;

        highestValue = highestValue_;
        totalDeposit = 0;
        valuesSubmitted = 0;
        generated = 0;
    }

    function getHash(uint value) public view returns(bytes32) {
        return keccak256(abi.encodePacked(msg.sender, value));
    }

    function submmitHash(bytes32 hash) external payable {
         // O jogo já terminou
        require(block.number > validUntil, "Periodo de apostas ainda nao terminou.");
        // O período de envio de hash ainda não terminou
        require(block.number <= hashValidUntil, "Periodo de submissao de hash ainda nao terminou.");
        // O depósito é igual ao maior valor possível
        require(msg.value == highestValue, "Deposito incorreto.");
        // Este endereço ainda não enviou um hash
        require(!submissionMap[msg.sender].submittedHash, "Hash ja submetido");
        
        submissionMap[msg.sender].submittedHash = true; // Registra a submissão do hash
        submissionMap[msg.sender].hash = hash; // Armazena o hash submetido
        totalDeposit += msg.value; // Adiciona o valor de depósito a soma total
    }

    function submmitValue(uint value) external payable {
        // Já terminou a fase de submeter hashes
        require(block.number > hashValidUntil, "Periodo de submissao de valor ainda nao comecou.");
        // Ainda não terminou a fase de submeter valores
        require(block.number <= valueValidUntil, "Peroodo de submissao de valor ja terminou.");
        // O valor está no intervalo exigido
        require(value <= highestValue, "Valor submetido maior que o exigido.");
        // Este endereço enviou um hash
        require(submissionMap[msg.sender].submittedHash, "Hash nao submetido.");
        // Este endereço ainda não enviou um valor
        require(!submissionMap[msg.sender].submittedValue, "Valor ja submetido.");
        
        bytes32 hash = keccak256(abi.encodePacked(msg.sender, value)); // Obtém o hash do valor e o endereço
        if (hash == submissionMap[msg.sender].hash) { // Compara com o hash submetido
            valuesSubmitted += 1; // Incrementa o número de valores submetidos
            generated = generated ^ value; // Computa o novo valor gerado
            submissionMap[msg.sender].submittedValue = true; // Registra a submissão deste endereço
        }
    }

    function cashbackDeposit() external {
        // Já terminou a fase de submissão de valores
        require(block.number > valueValidUntil, "Periodo de cashback ainda nao comecou.");
        // Ainda está na fase de retirar depósitos
        require(block.number <= cashbackValidUntil, "Periodo de cashback ja terminou");
        // O endereço submeteu um valor
        require(submissionMap[msg.sender].submittedValue, "Nenhum valor submetido.");
        // O endereço ainda não retirou o depósito
        require(!submissionMap[msg.sender].cashedBack, "Deposito ja retornado.");

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
