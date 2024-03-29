// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract MockNFT is ERC721 {
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

  constructor(
    string memory name,
    string memory symbol
  ) public ERC721(name, symbol) {}

  function mint(
    address receiver,
    string memory metadata
  ) public returns (uint256) {
    _tokenIds.increment();
    uint256 newItemId = _tokenIds.current();
    _mint(receiver, newItemId);
    return newItemId;
  }

  function currentTokenId() public view returns (uint256) {
    return _tokenIds.current();
  }
}
