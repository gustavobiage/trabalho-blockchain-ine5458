// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./Roulette.sol";

contract RouletteOnChainEntropy is Roulette {
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
        bytes32 hash = keccak256(abi.encodePacked(blockhash(256)));
        return uint(hash) % nColors;
    }

    function hasEnded() public view override returns(bool) {
        return block.number > validUntil;
    }
}