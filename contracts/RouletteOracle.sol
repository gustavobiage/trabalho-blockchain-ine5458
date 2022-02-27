
// SPDX-License-Identifier: GPL-3.0

pragma solidity >= 0.7.0 < 0.9.0;

import "./Roulette.sol";
import "./Oracle.sol";

contract RouletteOracle is Roulette {
    /**
     * Oráculo
     */
     VRFv2Consumer oracle;

    /**
     * Construtor;
     * @param c Refere-se ao número de cores na roleta (2^c).
     * @param token_ Define o preço de cada ficha apostada
     * @param tax_ Define a taxa de cada aposta que gera lucro para o proprietário do contrato.
     * @param gameDuration Duração que o contrato se encontra aberto para apostas
     */
    constructor(uint c, uint token_, uint tax_, uint gameDuration, uint64 subscriptionId) payable Roulette(c, token_, tax_, gameDuration) {
        oracle = new VRFv2Consumer(subscriptionId);
    }

    function selectColor() internal override returns(uint) {
        oracle.requestRandomWords();
        uint256 randomValue = oracle.s_randomWords(0);
        return randomValue % nColors;
    }

    function hasEnded() public view override returns(bool) {
        return block.number > validUntil;
    }
}
