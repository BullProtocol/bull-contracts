// SPDX-License-Identifier: MIT

pragma solidity 0.7.4;
import "./BSwapExchange.sol";
import "../interfaces/IBSwapFactory.sol";


contract BSwapFactory is IBSwapFactory {

  /***********************************|
  |       Events And Variables        |
  |__________________________________*/

  // tokensToExchange[erc1155_token_address][currency_address][currency_token_id]
  mapping(address => mapping(address => mapping(uint256 => address))) public override tokensToExchange;

  /***********************************|
  |            Constructor            |
  |__________________________________*/

  /**
   * @notice Creates a BSwap Exchange for given token contract
   * @param _token      The address of the ERC-1155 token contract
   * @param _currency   The address of the currency token contract
   * @param _currencyID The id of the currency token
   */
  function createExchange(address _token, address _currency, uint256 _currencyID) public override {
    require(tokensToExchange[_token][_currency][_currencyID] == address(0x0), "BSwapFactory#createExchange: EXCHANGE_ALREADY_CREATED");

    // Create new exchange contract
    BSwapExchange exchange = new BSwapExchange(_token, _currency, _currencyID);

    // Store exchange and token addresses
    tokensToExchange[_token][_currency][_currencyID] = address(exchange);

    // Emit event
    emit NewExchange(_token, _currency, _currencyID, address(exchange));
  }

}
