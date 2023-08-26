// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "../Business/BusinessNFT.sol";
// import "../Business/BusinessToken.sol";
import "hardhat/console.sol";

error PRIVATE__NOTOWNER();
error PRIVATE__TXFAILED();
error PRIVATE__NOTENOUGHFUNDS();
error PRIVATE__INVALIDLENGTH();
error PRIVATE__NOTENOUGHTFEE();

/**
 * @title Private tx with stealth payments
 * @author Shawn kimtai
 * @notice Contract that allows for payments where only the sender and receiver
 * know the destination of money.
 */

contract Private is ReentrancyGuard {
    using SafeMath for uint256;

    address internal constant ETH_TOKEN_PLACHOLDER =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address private i_owner;
    uint256 private s_fee;
    uint256 private _totalFee;
    uint256 private s_tokenFee;
    mapping(address => uint256) private _tokenTotalFee;

    event Announcement(
        address indexed receiver,
        uint256 amount,
        address indexed token,
        bytes32 pkx,
        bytes32 ciphertext
    );

    event TokenWithdrawal(bytes indexed data, address indexed tokenAddress);

    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert PRIVATE__NOTOWNER();
        }
        _;
    }

    modifier checkFee(uint256 len, uint256 amount) {
        if (amount < s_fee * len) {
            revert PRIVATE__NOTENOUGHTFEE();
        }
        _;
    }

    modifier IsTransferAllowed(uint256 tokenId, address businessNFTAddress) {
        if (businessNFTAddress != address(0)) {
            BusinessNFT businessNft = BusinessNFT(businessNFTAddress);
            if (businessNft.getSBT(tokenId)) {
                revert Account__CANNOTSENDSBT();
            }
            _;
        } else {
            _;
        }
    }

    constructor(uint256 payFee, uint256 tokenFee) {
        i_owner = msg.sender;
        s_fee = payFee;
        _totalFee = 0;
        s_tokenFee = tokenFee;
    }

    receive() external payable {}

    /**
     * @notice Send ETH to the stealth address
     * @param _recipient The stealth address
     * @param _pkx ephemeral public key x coordinate
     * @param _ciphertext Encrypted entropy (used to generated the stealth address)
     */
    function sendEth(
        address payable _recipient,
        bytes32 _pkx,
        bytes32 _ciphertext
    ) external payable checkFee(1, msg.value) {
        uint256 _amountSent;

        _amountSent = msg.value - s_fee;

        _totalFee += s_fee;

        (bool success, ) = _recipient.call{value: _amountSent}("");
        if (!success) {
            revert PRIVATE__TXFAILED();
        }
        emit Announcement(
            _recipient,
            _amountSent,
            ETH_TOKEN_PLACHOLDER,
            _pkx,
            _ciphertext
        );
    }

    /**
     * @notice Send ETH to many recipients
     * @param _recipient Array of stealth addresses
     * @param _pkx Arrays of ephemeral public key x coordinates
     * @param _ciphertext Array of Encrypted entropys (used to generated the stealth addresses)
     * @param _amount Array of amounts to be sent to stealth addresses
     */
    function sendEthToMany(
        address payable[] calldata _recipient,
        uint256[] calldata _amount,
        bytes32[] calldata _pkx,
        bytes32[] calldata _ciphertext
    ) external payable {
        uint256 len = _recipient.length;

        if (
            len != _amount.length ||
            len != _pkx.length ||
            len != _ciphertext.length
        ) {
            revert PRIVATE__INVALIDLENGTH();
        }

        getEachAmount(_amount, address(0));

        for (uint256 i = 0; i < len; ) {
            (bool success, ) = _recipient[i].call{value: _amount[i] - s_fee}(
                ""
            );
            if (!success) {
                revert PRIVATE__TXFAILED();
            }
            emit Announcement(
                _recipient[i],
                _amount[i],
                ETH_TOKEN_PLACHOLDER,
                _pkx[i],
                _ciphertext[i]
            );
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Send ERC20 to stealth address
     * @param _recipient The stealth address of the recipient
     * @param _tokenAddr Token address of the ERC20 token
     * @param _amount Amount to send to stealth address
     * @param _pkx ephemeral public key x coordinate
     * @param _ciphertext Encrypted entropy (used to generated the stealth address)
     */

    function sendERC20(
        address _recipient,
        address _tokenAddr,
        uint256 _amount,
        bytes32 _pkx,
        bytes32 _ciphertext
    ) external {
        uint256 _amountSent;

        _amountSent = _amount - s_tokenFee;
        _tokenTotalFee[_tokenAddr] += s_tokenFee;

        bool success = IERC20(_tokenAddr).transfer(_recipient, _amountSent);

        if (!success) {
            revert PRIVATE__TXFAILED();
        }
        emit Announcement(_recipient, _amount, _tokenAddr, _pkx, _ciphertext);
    }

    /**
     * @notice Send ERC20 to many Stealth addresses
     * @param _recipient Array of stealth addresses
     * @param _tokenAddr The ERC20 token address
     * @param _pkx Arrays of ephemeral public key x coordinates
     * @param _ciphertext Array of Encrypted entropys (used to generated the stealth addresses)
     * @param _amount Array of amounts to be sent to stealth addresses
     */

    function sendERC20ToMany(
        address payable[] calldata _recipient,
        address _tokenAddr,
        uint256[] calldata _amount,
        bytes32[] calldata _pkx,
        bytes32[] calldata _ciphertext
    ) external {
        uint256 len = _recipient.length;

        if (
            len != _amount.length ||
            len != _pkx.length ||
            len != _ciphertext.length
        ) {
            revert PRIVATE__INVALIDLENGTH();
        }

        getEachAmount(_amount, _tokenAddr);

        for (uint256 i = 0; i < len; ) {
            bool success = IERC20(_tokenAddr).transfer(
                _recipient[i],
                _amount[i] - s_tokenFee
            );
            if (!success) {
                revert PRIVATE__TXFAILED();
            }
            emit Announcement(
                _recipient[i],
                _amount[i],
                _tokenAddr,
                _pkx[i],
                _ciphertext[i]
            );
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Send ERC721 to stealth address
     * @param _recipient The recipient of ERC721
     * @param _tokenAddr Token Address of the ERC721
     * @param _businessTokenAddr Business ERC721 token address. Can be null
     * @param _tokenId Token Id of the ERC721
     * @param _pkx ephemeral public key x coordinate
     * @param _ciphertext Encrypted entropy (used to generated the stealth address)
     */

    function sendERC721(
        address payable _recipient,
        address _tokenAddr,
        address _businessTokenAddr,
        uint256 _tokenId,
        bytes32 _pkx,
        bytes32 _ciphertext
    )
        external
        payable
        IsTransferAllowed(_tokenId, _businessTokenAddr)
        checkFee(1, msg.value)
    {
        if (msg.value < s_fee) {
            revert PRIVATE__NOTENOUGHFUNDS();
        }
        uint amountToSend = msg.value - s_fee;

        _totalFee += s_fee;

        IERC721(_tokenAddr).safeTransferFrom(msg.sender, _recipient, _tokenId);
        //This is to help with sending NFT with a stealth address
        //that has no eth to pay gas
        if (amountToSend > 0) {
            (bool success, ) = _recipient.call{value: amountToSend}("");

            if (!success) {
                revert PRIVATE__TXFAILED();
            }
        }

        emit Announcement(_recipient, _tokenId, _tokenAddr, _pkx, _ciphertext);
    }

    /**
     * @notice This allows users to send ETH to business stealth address
     * @param _tokenId Token Id of the business NFT
     * @param _recipient The stealth address
     * @param _amount Amount to send to stealth address
     * @param _businessTokenAddress The business Token address
     * @param _businessNFTAddress Business NFT address
     * @param _pkx ephemeral public key x coordinate
     * @param _ciphertext Encrypted entropy (used to generated the stealth address)
     */

    function sendToBusiness(
        uint256 _tokenId,
        address payable _recipient,
        uint256 _amount,
        address _businessTokenAddress,
        address _businessNFTAddress,
        bytes32 _pkx,
        bytes32 _ciphertext
    ) external checkFee(1, _amount) {
        uint256 amountToSend;

        amountToSend = _amount - s_fee;

        _totalFee += s_fee;

        (uint256 changeAmountToSend, uint256 tokenToSend) = getBusinessDiscount(
            _businessTokenAddress,
            _businessNFTAddress,
            msg.sender,
            address(0),
            _tokenId,
            amountToSend
        );

        (bool success, ) = _recipient.call{value: changeAmountToSend}("");
        bool tokenSuccess = IERC20(_businessTokenAddress).transfer(
            _recipient,
            tokenToSend
        );
        if (!success || !tokenSuccess) {
            revert PRIVATE__TXFAILED();
        }
        emit Announcement(
            _recipient,
            _amount,
            ETH_TOKEN_PLACHOLDER,
            _pkx,
            _ciphertext
        );
    }

    /**
     * @notice This allows users to send ERC20 to business stealth address
     * @param _tokenId Token Id of the business NFT
     * @param _recipient The stealth address
     * @param _tokenAddr The ERC20 token address
     * @param _amount Amount to send to stealth address
     * @param _businessTokenAddress The business Token address
     * @param _businessNFTAddress Business NFT address
     * @param _pkx ephemeral public key x coordinate
     * @param _ciphertext Encrypted entropy (used to generated the stealth address)
     */

    function sendERC20ToBusiness(
        address payable _recipient,
        address _tokenAddr,
        address _businessTokenAddress,
        address _businessNFTAddress,
        uint256 _tokenId,
        uint256 _amount,
        bytes32 _pkx,
        bytes32 _ciphertext
    ) external {
        _amount -= s_tokenFee;
        _tokenTotalFee[_tokenAddr] += s_tokenFee;

        _amount.mul(10 ** 18);

        (uint256 changeAmountToSend, uint256 tokenToSend) = getBusinessDiscount(
            _businessTokenAddress,
            _businessNFTAddress,
            msg.sender,
            _tokenAddr,
            _tokenId,
            _amount
        );

        bool success = IERC20(_tokenAddr).transfer(
            _recipient,
            changeAmountToSend
        );
        bool tokenSuccess = IERC20(_businessTokenAddress).transfer(
            _recipient,
            tokenToSend
        );
        if (!success || !tokenSuccess) {
            revert PRIVATE__TXFAILED();
        }
        emit Announcement(
            _recipient,
            _amount,
            ETH_TOKEN_PLACHOLDER,
            _pkx,
            _ciphertext
        );
    }

    function withdrawEthFee(
        address payable _to,
        uint256 _amount
    ) external nonReentrant onlyOwner {
        if (_totalFee < _amount) {
            revert PRIVATE__NOTENOUGHFUNDS();
        }

        (bool success, ) = _to.call{value: _amount}("");
        if (!success) {
            revert PRIVATE__TXFAILED();
        }
    }

    function withdrawTokenFee(
        address payable _to,
        uint256 _amount,
        address _tokenAddress
    ) external nonReentrant onlyOwner {
        if (_tokenTotalFee[_tokenAddress] < _amount) {
            revert PRIVATE__NOTENOUGHFUNDS();
        }

        bool success = IERC20(_tokenAddress).transfer(_to, _amount);
        if (!success) {
            revert PRIVATE__TXFAILED();
        }
    }

    /**
     * @notice Withdraw token sent to stealth address
     * @param _data data to send with the function
     * @param _to Address to perform data on
     */
    function stealthWithdrawToken(bytes calldata _data, address _to) external {
        _withdrawToken(_data, _to);
    }

    /**
     * @notice Withdraw token sent to stealth address
     * @param _data Data to send with the function
     * @param _to Address to perform data on
     */
    function withdrawTokenAndCall(bytes calldata _data, address _to) external {
        _withdrawToken(_data, _to);
    }

    /**
     * @param _data Address to send token to
     * @param _to Address to perform data on
     */
    function _withdrawToken(bytes calldata _data, address _to) private {
        (bool success, ) = _to.call(_data);
        if (!success) {
            revert PRIVATE__TXFAILED();
        }

        emit TokenWithdrawal(_data, _to);
    }

    function changeFee(uint256 _newFee) external onlyOwner {
        s_fee = _newFee;
    }

    function changeOwner(address newOwner) external onlyOwner {
        i_owner = newOwner;
    }

    function changeTokenFee(uint256 _newTokenFee) external onlyOwner {
        s_tokenFee = _newTokenFee;
    }

    function getFee() external view returns (uint256) {
        return s_fee;
    }

    function getTokenFee() external view returns (uint256) {
        return s_tokenFee;
    }

    function getEachAmount(
        uint256[] calldata _amount,
        address tokenAddress
    ) private {
        uint256 len = _amount.length;

        for (uint256 j = 0; j < len; ) {
            for (uint256 i = 0; i < len; i++) {
                uint256 totalAmount;
                tokenAddress == address(0)
                    ? totalAmount += _amount[i]
                    : totalAmount += _amount[i];
                if (tokenAddress == address(0)) {
                    if (totalAmount < s_fee * _amount.length) {
                        revert PRIVATE__NOTENOUGHTFEE();
                    }
                } else {
                    if (totalAmount < s_tokenFee * _amount.length) {
                        revert PRIVATE__NOTENOUGHTFEE();
                    }
                }
                unchecked {
                    ++i;
                }
            }

            tokenAddress == address(0)
                ? _totalFee += (_amount[j] - s_fee)
                : _tokenTotalFee[tokenAddress] += (_amount[j] - s_tokenFee);

            unchecked {
                ++j;
            }
        }
    }

    function getBusinessDiscount(
        address _businessTokenAddress,
        address _businessNFTAddress,
        address _sender,
        address _erc20Addr,
        uint256 _tokenId,
        uint256 _amount
    ) private view returns (uint256 amountToSend, uint256 tokenToSend) {
        BusinessToken businessToken = BusinessToken(_businessTokenAddress);
        BusinessNFT businessNft = BusinessNFT(_businessNFTAddress);

        uint256 businessTokenBalance;
        uint256 NFTSBTDiscount;
        amountToSend = _amount;

        if (
            _businessNFTAddress == address(0) &&
            _businessTokenAddress != address(0)
        ) {
            NFTSBTDiscount = 0;
            businessTokenBalance = businessToken.getBuyerBalance(
                address(_sender)
            );
        } else if (
            _businessTokenAddress == address(0) &&
            _businessNFTAddress != address(0)
        ) {
            businessTokenBalance == 0;
            NFTSBTDiscount = businessNft.getNFTSBTDiscount(
                address(_sender),
                _tokenId
            );
        } else if (
            _businessNFTAddress == address(0) &&
            _businessTokenAddress == address(0)
        ) {
            businessTokenBalance == 0;
            NFTSBTDiscount = 0;
        } else {
            businessTokenBalance = businessToken.getBuyerBalance(
                address(_sender)
            );

            NFTSBTDiscount = businessNft.getNFTSBTDiscount(
                address(_sender),
                _tokenId
            );
        }

        uint256 totalDiscount = ((businessTokenBalance * 10 ** 18) +
            NFTSBTDiscount);

        if (amountToSend < totalDiscount) {
            tokenToSend = NFTSBTDiscount >= amountToSend
                ? 0
                : (amountToSend - NFTSBTDiscount).div(10 ** 18); //ahould we add one
            amountToSend = 0;
        } else if (amountToSend > totalDiscount) {
            tokenToSend = businessTokenBalance;
            _erc20Addr == address(0)
                ? amountToSend -= totalDiscount
                : amountToSend = (amountToSend - totalDiscount).div(10 ** 18);
        } else {
            tokenToSend = businessTokenBalance;
            amountToSend = 0;
        }
    }
}
