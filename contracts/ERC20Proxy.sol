// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LibBytes} from "./libs/LibBytes.sol";
import {Authorizable} from "./Authorizable.sol";
import {IAssetProxy} from "./interfaces/IAssetProxy.sol";

contract ERC20Proxy is Authorizable, IAssetProxy {
  using LibBytes for bytes;

  mapping(address => bool) public whitelistedTokens;

  // Id of this proxy.
  bytes4 internal constant PROXY_ID = bytes4(keccak256("ERC20Token(address)"));

  function addToken(address token) external onlyOwner {
    whitelistedTokens[token] = true;
  }

  function removeToken(address token) external onlyOwner {
    whitelistedTokens[token] = false;
  }

  function transferFrom(
    bytes calldata assetData,
    address from,
    address to,
    uint256 amount
  ) external override onlyAuthorized {
    // Decode params from `assetData`
    // solhint-disable indent
    address erc20TokenAddress = abi.decode(
      assetData.sliceDestructive(4, assetData.length),
      (address)
    );

    require(
      whitelistedTokens[erc20TokenAddress],
      "ERC20PROXY: token is not whitelisted"
    );
    // solhint-enable indent

    // Execute `safeBatchTransferFrom` call
    // Either succeeds or throws
    IERC20(erc20TokenAddress).transferFrom(from, to, amount);
  }

  /// @dev Gets the proxy id associated with the proxy address.
  /// @return Proxy id.
  function getProxyId() external pure override returns (bytes4) {
    return PROXY_ID;
  }
}
