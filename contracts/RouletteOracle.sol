// SPDX-License-Identifier: MIT
// An example of a consumer contract that relies on a subscription for funding.
pragma solidity ^0.8.7;

import "./Roulette.sol";
import "./Oracle.sol";

contract RouletteOracle is Roulette {
    /**
     * Oráculo
     */
    VRFv2Consumer public oracle;
    /**
     * Oráculo contactado
     */
    bool public oracleContacted;

    /**
     * Construtor;
     * @param c Refere-se ao número de cores na roleta (2^c).
     * @param token_ Define o preço de cada ficha apostada
     * @param tax_ Define a taxa de cada aposta que gera lucro para o proprietário do contrato.
     * @param gameDuration Duração que o contrato se encontra aberto para apostas
     */
    constructor(uint c, uint token_, uint tax_, uint gameDuration, uint64 subscriptionId) payable Roulette(c, token_, tax_, gameDuration) {
        oracle = new VRFv2Consumer(msg.sender, subscriptionId);
        oracleContacted = false;
    }

    function selectColor() internal view override returns(uint) {
        uint256 randomValue = oracle.s_randomWord();
        return randomValue % nColors;
    }

    function contactOracle() external {
        require(block.number > validUntil, "O periodo de apostas ainda nao acabou");
        require(!oracleContacted, "Oraculo ja contactado.");
        oracle.requestRandomWords();
        oracleContacted = true;
    }

    function hasEnded() public view override returns(bool) {
        return oracle.stored() && block.number > validUntil;
    }
}