//SPDX-License-Identifier:MIT

pragma solidity 0.8.20;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * @title CollateralisedLending
 * @author Megabyte
 * @notice The is a very basic collateralised lending contract. In this contract user can deposit different ERC20 tokens as collaterals whose price are constant at 1 ether. The user can borrow ETH against the collateralised tokens. The user can also repay the borrowed ETH. The user can also liquidate the collateral of the borrower if the threshold is reached.
 */
contract CollateralisedLending {
    /*
        ___ _ __ _ __ ___  ___
       / _ \ '__| '__/ _ \/ __|
      |  __/ |  | | | (_) \__ \
       \___|_|  |_|  \___/|___/
    */
    error CollateralisedLending__ZeroAmount();
    error CollateralisedLending__ZeroAddress();
    error CollateralisedLending__NotAcceptedToken();
    error CollateralisedLending__NotEnoughBalance();
    error CollateralisedLending__DepositFailed();
    error CollateralisedLending__NotEnoughCollateral();
    error CollateralisedLending__BorrowFailed();
    error CollateralisedLending__NoBorrowedAmount();
    error CollateralisedLending__WrongAmount();
    error CollateralisedLending__RepaymentFailed();
    error CollateralisedLending__ThresholdNotReached();
    error CollateralisedLending__LiquidiationFailed();

    /*
                            _
        _____   _____ _ __ | |_ ___
       / _ \ \ / / _ \ '_ \| __/ __|
      |  __/\ V /  __/ | | | |_\__ \
       \___| \_/ \___|_| |_|\__|___/
    */
    event CollateralisedLending__TokenSet(address _token);
    event CollateralisedLending__CollateralDeposited(
        address indexed _user, address indexed _token, uint256 indexed _depositedAmount
    );
    event CollateralisedLending__CollateralBorrowed(
        address indexed _user, address indexed _token, uint256 indexed _borrowedAmount
    );
    event CollateralisedLending__CollateralRepaid(
        address indexed _user, address indexed _token, uint256 indexed _repaidAmount
    );
    event CollateralisedLending__CollateralLiquidated(
        address indexed _user, address indexed _token, uint256 indexed _liquidatedAmount
    );

    /*
           _        _                         _       _     _
       ___| |_ __ _| |_ ___  __   ____ _ _ __(_) __ _| |__ | | ___  ___
      / __| __/ _` | __/ _ \ \ \ / / _` | '__| |/ _` | '_ \| |/ _ \/ __|
      \__ \ || (_| | ||  __/  \ V / (_| | |  | | (_| | |_) | |  __/\__ \
      |___/\__\__,_|\__\___|   \_/ \__,_|_|  |_|\__,_|_.__/|_|\___||___/
    */
    uint256 public constant L2V_RATIO = 80;
    uint256 public constant PRECESION = 1e18;
    uint256 public constant PRICE = 1 ether;

    mapping(address _token => bool _isAccepted) public acceptedTokens;
    mapping(address _user => mapping(address _token => uint256 _amount)) public userCollateral;
    mapping(address _user => mapping(address _token => uint256 _amount)) public userBorrowed;

    /*
                           _ _  __ _
       _ __ ___   ___   __| (_)/ _(_) ___ _ __ ___
      | '_ ` _ \ / _ \ / _` | | |_| |/ _ \ '__/ __|
      | | | | | | (_) | (_| | |  _| |  __/ |  \__ \
      |_| |_| |_|\___/ \__,_|_|_| |_|\___|_|  |___/
    */

    modifier isZeroAmount(uint256 _amount) {
        if (_amount <= 0) {
            revert CollateralisedLending__ZeroAmount();
        }
        _;
    }

    modifier isZeroAddress(address _address) {
        if (_address == address(0)) {
            revert CollateralisedLending__ZeroAddress();
        }
        _;
    }

    modifier isTokenAccepted(address _token) {
        if (!acceptedTokens[_token]) {
            revert CollateralisedLending__NotAcceptedToken();
        }
        _;
    }

    /*
                   _     _ _         __                  _   _
       _ __  _   _| |__ | (_) ___   / _|_   _ _ __   ___| |_(_) ___  _ __  ___
      | '_ \| | | | '_ \| | |/ __| | |_| | | | '_ \ / __| __| |/ _ \| '_ \/ __|
      | |_) | |_| | |_) | | | (__  |  _| |_| | | | | (__| |_| | (_) | | | \__ \
      | .__/ \__,_|_.__/|_|_|\___| |_|  \__,_|_| |_|\___|\__|_|\___/|_| |_|___/
      |_|
    */

    /**
     * Function to add the tokens which are accepted as collateral.
     * @param _token address of the token to be accepted
     */
    function setAcceptedToken(address _token) public isZeroAddress(_token) {
        acceptedTokens[_token] = true;
    }

    /**
     * Function to add the collateral to the contract.
     * @param _token The token to be collateralised.
     * @param _amount The amount of token to be collateralised.
     * @notice only tokens in acceptedTokens mapping are accepted as collateral.
     * @notice Approval of the collateral token is required before calling this function.
     */
    function depositCollateral(address _token, uint256 _amount)
        public
        isZeroAddress(_token)
        isZeroAmount(_amount)
        isTokenAccepted(_token)
    {
        uint256 _userBalance = IERC20(_token).balanceOf(msg.sender);

        if (_userBalance < _amount) {
            revert CollateralisedLending__NotEnoughBalance();
        }

        userCollateral[msg.sender][_token] += _amount;

        // sends the collateral token from the user to the contract
        (bool success,) = address(_token).call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", msg.sender, address(this), _amount)
        );
        if (!success) {
            revert CollateralisedLending__DepositFailed();
        } else {
            emit CollateralisedLending__CollateralDeposited(msg.sender, _token, _amount);
        }
    }

    /**
     * Function to borrow the collateral token.
     * @param _token The collateral token to be utilised for borrowing ETH.
     * @param _amount The amount of token to be utilised for borrowing ETH.
     * @notice The user can only borrow ETH.
     */
    function borrowAsset(address _token, uint256 _amount)
        public
        isZeroAddress(_token)
        isZeroAmount(_amount)
        isTokenAccepted(_token)
    {
        uint256 _userBorrowableAmount = _borrowableAmount(_token, msg.sender);
        if (_userBorrowableAmount < _amount) {
            revert CollateralisedLending__NotEnoughCollateral();
        }

        userBorrowed[msg.sender][_token] += _amount;

        uint256 _totalETH = _amount * PRICE;

        // send the ETH equivalent of the _userBorrowableAmount from the contract to the user
        (bool success,) = msg.sender.call{value: _totalETH}("");

        if (!success) {
            revert CollateralisedLending__BorrowFailed();
        } else {
            emit CollateralisedLending__CollateralBorrowed(msg.sender, _token, _amount);
        }
    }

    /**
     * Function to repay the borrowed collateral token in ETH.
     * @param _token The collateral token to be repaid in ETH.
     * @param _amount The amount of toekn to be repaid in ETH.
     */
    function repayLoan(address _token, uint256 _amount)
        public
        payable
        isZeroAmount(_amount)
        isZeroAddress(_token)
        isTokenAccepted(_token)
    {
        uint256 _userBorrowedAmount = userBorrowed[msg.sender][_token];
        if (_userBorrowedAmount <= 0) {
            revert CollateralisedLending__NoBorrowedAmount();
        }

        if (_userBorrowedAmount < _amount) {
            revert CollateralisedLending__WrongAmount();
        }

        userBorrowed[msg.sender][_token] -= _amount;

        uint256 totalRepayableETH = _amount * PRICE;
        if (msg.value != totalRepayableETH) {
            revert CollateralisedLending__WrongAmount();
        } else {
            emit CollateralisedLending__CollateralRepaid(msg.sender, _token, _amount);
        }
    }

    /**
     * Function to liquidate the collateral of the borrower if the threshold is reached.
     * @param _token The collateral token to be liquidated.
     * @param _borrower The borrower whose collateral is to be liquidated.
     * @notice The user can only liquidate the collateral of the borrower in ETH.
     */
    function liquidateCollateral(address _token, address _borrower)
        public
        payable
        isZeroAddress(_borrower)
        isZeroAddress(_token)
        isTokenAccepted(_token)
    {
        bool reachedThreashold = _isThresholdReached(_token, _borrower);

        if (!reachedThreashold) {
            revert CollateralisedLending__ThresholdNotReached();
        }

        uint256 _userCollateralAmount = userCollateral[_borrower][_token];

        if (_userCollateralAmount < msg.value) {
            revert CollateralisedLending__WrongAmount();
        }

        (bool success,) = address(_token).call(
            abi.encodeWithSignature("transfer(address,uint256)", msg.sender, _userCollateralAmount)
        );

        if (!success) {
            revert CollateralisedLending__LiquidiationFailed();
        } else {
            emit CollateralisedLending__CollateralLiquidated(msg.sender, _token, _userCollateralAmount);
        }
    }

    /*
       _       _                        _    __                  _   _
      (_)_ __ | |_ ___ _ __ _ __   __ _| |  / _|_   _ _ __   ___| |_(_) ___  _ __  ___
      | | '_ \| __/ _ \ '__| '_ \ / _` | | | |_| | | | '_ \ / __| __| |/ _ \| '_ \/ __|
      | | | | | ||  __/ |  | | | | (_| | | |  _| |_| | | | | (__| |_| | (_) | | | \__ \
      |_|_| |_|\__\___|_|  |_| |_|\__,_|_| |_|  \__,_|_| |_|\___|\__|_|\___/|_| |_|___/
    */

    /**
     * Function to check whether the threshold is reached or not for a borrower with sepicific token.
     * @param _token The collateral token.
     * @param _borrower The borrower whose threshold is to be checked.
     */
    function _isThresholdReached(address _token, address _borrower) internal view returns (bool isReached) {
        uint256 _borrowableAmt = _borrowableAmount(_token, _borrower);
        if (_borrowableAmt <= 0) {
            isReached = true;
        } else {
            isReached = false;
        }
    }

    /**
     * Fucntion to calculate the amount of ETH that can be borrowed by the user against the collateral token provided.
     * @param _token The collateral token.
     * @param _user The user whose borrowable amount is to be calculated.
     */
    function _borrowableAmount(address _token, address _user) internal view returns (uint256 _amount) {
        uint256 _userCollateralAmount = userCollateral[_user][_token];
        if (_userCollateralAmount <= 0) {
            return 0;
        }

        uint256 _userBorrowedAmount = userBorrowed[_user][_token];

        // Precision
        uint256 _precisedAmount = (_userCollateralAmount * L2V_RATIO * PRECESION) / (100 * PRECESION);

        _amount = (_precisedAmount - _userBorrowedAmount) * PRICE;
    }
}
