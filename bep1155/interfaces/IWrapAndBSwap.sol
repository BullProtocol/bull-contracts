// SPDX-License-Identifier: MIT

pragma solidity 0.7.4;

interface IWrapAndBSwap {

  /**
   * @notice Wrap ERC-20 to ERC-1155 and swap them
   * @dev User must approve this contract for ERC-20 first
   * @param _maxAmount       Maximum amount of ERC-20 user wants to spend
   * @param _recipient       Address where to send tokens
   * @param _bswapOrder  Encoded BSwap order passed in data field of safeTransferFrom()
   */
  function wrapAndSwap(uint256 _maxAmount, address _recipient, bytes calldata _bswapOrder) external;

  /**
   * @notice Accepts only tokenWrapper tokens
   * @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
   */
  function onERC1155Received(address _operator, address _from, uint256 _id, uint256 _amount, bytes calldata _data) external returns(bytes4);

  /**
   * @notice If receives tracked ERC-1155, it will send a sell order to bswap and unwrap received
   *         wrapped token. The unwrapped tokens will be sent to the sender.
   * @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
   */
  function onERC1155BatchReceived(address, address _from, uint256[] calldata _ids, uint256[] calldata _amounts, bytes calldata _data) external returns(bytes4);
}