// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

/**
 * @title BuffCoupons
 * @author Gabriel Antony Xaviour
 * @dev A contract for creating and managing BuffCoupons tokens.
 */
interface IBuffCoupons {
  /**
   * @dev Creates a new token with the specified URI and price.
   * @param _uri The URI for the token's metadata.
   * @param price The price of the token.
   */
  function createToken(string memory _uri, uint256 price) external;

  /**
   * @dev Updates the price of an existing token.
   * @param tokenId The ID of the token to update.
   * @param price The new price for the token.
   */
  function updateTokenPrice(uint256 tokenId, uint256 price) external;

  /**
   * @dev Sets the URI for a specific token.
   * @param tokenId The ID of the token to update.
   * @param newuri The new URI for the token's metadata.
   */
  function setURI(uint256 tokenId, string memory newuri) external;

  /**
   * @dev Mints tokens to a specified account.
   * @param account The account to mint tokens to.
   * @param id The ID of the token to mint.
   * @param data Optional data to pass to the recipient.
   */
  function mint(
    address account,
    uint256 id,
    bytes memory data
  ) external;

  /**
   * @dev Returns the URI for a given token ID.
   * @param tokenId The ID of the token.
   * @return The URI of the token's metadata.
   */
  function uri(uint256 tokenId) external view returns (string memory);

  /**
   * @dev Checks if a token with the given ID exists.
   * @param tokenId The ID of the token.
   * @return A boolean indicating whether the token exists.
   */
  function tokenExists(uint256 tokenId) external view returns (bool);

  /**
   * @dev Returns the total number of tokens created.
   * @return The total number of tokens.
   */
  function getTotalTokens() external view returns (uint256);

  /**
   * @dev Checks if the specified number of tokens can be afforded for a given token.
   * @param tokenId The ID of the token.
   * @param tokens The number of tokens to check affordability for.
   * @return A boolean indicating whether the tokens can be afforded.
   */
  function isAffordable(uint256 tokenId, uint256 tokens) external view returns (bool);

  /**
   * @dev Returns the price of a given token.
   * @param tokenId The ID of the token.
   * @return The price of the token.
   */
  function getTokenPrice(uint256 tokenId) external view returns (uint256);

  // Events
  /**
   * @dev Emitted when a new token is created.
   * @param tokenId The ID of the created token.
   * @param uri The URI of the token's metadata.
   * @param timestamp The timestamp of the event.
   */
  event TokenCreated(uint256 tokenId, string uri, uint256 timestamp);

  /**
   * @dev Emitted when tokens are minted to an account.
   * @param tokenId The ID of the minted token.
   * @param to The account to which the tokens are minted.
   * @param price The price of the minted tokens.
   * @param timestamp The timestamp of the event.
   */
  event TokenMinted(uint256 tokenId, address to, uint256 price, uint256 timestamp);

  /**
   * @dev Emitted when the price of a token is updated.
   * @param tokenId The ID of the token.
   * @param price The updated price of the token.
   * @param timestamp The timestamp of the event.
   */
  event TokenPriceUpdated(uint256 tokenId, uint256 price, uint256 timestamp);

  /**
   * @dev Emitted when the URI of a token is updated.
   * @param tokenId The ID of the token.
   * @param uri The updated URI of the token's metadata.
   * @param timestamp The timestamp of the event.
   */
  event TokenURIUpdated(uint256 tokenId, string uri, uint256 timestamp);
}
