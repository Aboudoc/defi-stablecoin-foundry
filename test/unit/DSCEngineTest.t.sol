// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {MockFailedMintDSC} from "../mocks/MockFailedMintDSC.sol";
import {MockFailedTransferFrom} from "../mocks/MockFailedTransferFrom.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig config;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;
    uint256 public constant AMOUNT_TO_MINT = 1000 ether;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth,,) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    ///////////////////////////
    // Constructor Tests
    ///////////////////////////
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    ///////////////////
    // Price Tests
    ///////////////////

    function testGetUsdValue() public {
        uint256 ethAmount = 15e18;
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = dsce.getUsdValue(weth, ethAmount);
        assertEq(actualUsd, expectedUsd);
    }

    function testGetTokenAmountFromUsd() public {
        uint256 usdAmount = 100 ether;
        uint256 expectedEthAmount = 0.05 ether;
        uint256 actualEthAmount = dsce.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(actualEthAmount, expectedEthAmount);
    }

    ///////////////////////////
    // depositCollateral Tests
    ///////////////////////////

    // RETRY THIS ONE
    //[FAIL. Reason: Call did not revert as expected]

    // function testRevertsIfTransferFromFailed() public {
    //     MockFailedTransferFrom mockDsc = new MockFailedTransferFrom();

    //     tokenAddresses = [address(mockDsc)];
    //     priceFeedAddresses = [ethUsdPriceFeed];

    //     vm.prank(USER);
    //     DSCEngine mockDsce = new DSCEngine(tokenAddresses, priceFeedAddresses, address(mockDsc));

    //     mockDsc.mint(USER, AMOUNT_COLLATERAL);

    //     vm.startPrank(USER);
    //     mockDsc.transferOwnership(address(mockDsce));
    //     ERC20Mock(address(mockDsc)).approve(address(mockDsce), AMOUNT_COLLATERAL);
    //     vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
    //     dsce.depositCollateral(address(mockDsc), AMOUNT_COLLATERAL);
    //     vm.stopPrank();
    // }

    function testRevertsIfTransferFromFails() public {
        // Arrange - Setup
        address owner = msg.sender;
        vm.prank(owner);
        MockFailedTransferFrom mockDsc = new MockFailedTransferFrom();
        tokenAddresses = [address(mockDsc)];
        priceFeedAddresses = [ethUsdPriceFeed];
        vm.prank(owner);
        DSCEngine mockDsce = new DSCEngine(
            tokenAddresses,
            priceFeedAddresses,
            address(mockDsc)
        );
        mockDsc.mint(USER, AMOUNT_COLLATERAL);

        vm.prank(owner);
        mockDsc.transferOwnership(address(mockDsce));
        // Arrange - User
        vm.startPrank(USER);
        ERC20Mock(address(mockDsc)).approve(address(mockDsce), AMOUNT_COLLATERAL);
        // Act / Assert
        vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
        mockDsce.depositCollateral(address(mockDsc), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testRevertsIfCollateralIsZero() public {
        vm.prank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock ranToken = new ERC20Mock();
        vm.startPrank(USER);
        ranToken.mint(USER, AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        dsce.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testCanDepositWithoutMinting() public {}

    function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(USER);

        uint256 expectedTotalDscMinted = 0;
        uint256 expectedDepositAmount = dsce.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assertEq(totalDscMinted, expectedTotalDscMinted);
        assertEq(AMOUNT_COLLATERAL, expectedDepositAmount);
    }

    // TODO forge coverage --report debug ~85% coverage

    ///////////////////////////////////////
    // depositCollateralAndMintDsc Tests //
    ///////////////////////////////////////

    function testRevertsIfMintedDscBreaksHealthFactor() public {
        (, int256 price,,,) = MockV3Aggregator(ethUsdPriceFeed).latestRoundData();

        uint256 amountToMint =
            (AMOUNT_COLLATERAL * (uint256(price) * dsce.getAdditionalFeedPrecision())) / dsce.getPrecision();

        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        uint256 expectedHealthFactor =
            dsce.calculateHealthFactor(dsce.getUsdValue(weth, AMOUNT_COLLATERAL), amountToMint);

        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, expectedHealthFactor));
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, amountToMint);
        vm.stopPrank();
    }

    modifier depositedCollateralAndMintedDsc() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralAndMintDsc() public depositedCollateralAndMintedDsc {
        (uint256 totalDscMinted,) = dsce.getAccountInformation(USER);

        assertEq(totalDscMinted, AMOUNT_TO_MINT);
    }

    ///////////////////////////////////
    // mintDsc Tests //
    ///////////////////////////////////

    // This test needs it's own custom setup
    function testRevertsIfMintFails() public {
        MockFailedMintDSC failedDsce = new MockFailedMintDSC();
        tokenAddresses = [weth];
        priceFeedAddresses = [ethUsdPriceFeed];
        DSCEngine failedEngine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(failedDsce));

        failedDsce.transferOwnership(address(failedEngine));

        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(failedEngine), AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__MintFailed.selector);
        failedEngine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        vm.stopPrank();
    }

    function testMintRevertsIfMintsZero() public depositedCollateral {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.mintDsc(0);
        vm.stopPrank();
    }

    function testMintRevertsIfHealthFactorIsBroken() public depositedCollateral {
        (, int256 price,,,) = MockV3Aggregator(ethUsdPriceFeed).latestRoundData();

        uint256 amountToMint =
            (AMOUNT_COLLATERAL * (uint256(price) * dsce.getAdditionalFeedPrecision())) / dsce.getPrecision();

        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        uint256 expectedHealthFactor =
            dsce.calculateHealthFactor(dsce.getUsdValue(weth, AMOUNT_COLLATERAL), amountToMint);

        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, expectedHealthFactor));
        dsce.mintDsc(amountToMint);

        vm.stopPrank();
    }

    function testCanMintDsc() public depositedCollateral {
        vm.startPrank(USER);
        dsce.mintDsc(AMOUNT_TO_MINT);
        uint256 expectedDscBalance = dsc.balanceOf(USER);
        assertEq(expectedDscBalance, AMOUNT_TO_MINT);
        vm.stopPrank();
    }

    ///////////////////////////////////
    // burnDsc Tests //
    ///////////////////////////////////

    function testBurnRevertsIfBurnsZero() public depositedCollateralAndMintedDsc {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.burnDsc(0);
        vm.stopPrank();
    }

    function testCanBurnDsc() public depositedCollateralAndMintedDsc {
        vm.startPrank(USER);
        dsc.approve(address(dsce), AMOUNT_TO_MINT);
        dsce.burnDsc(AMOUNT_TO_MINT);
        uint256 expectedDscBalance = dsc.balanceOf(USER);
        assertEq(expectedDscBalance, 0);
        vm.stopPrank();
    }

    ///////////////////////////////////
    // redeemCollateral Tests //
    //////////////////////////////////

    ///////////////////////////////////
    // redeemCollateralForDsc Tests //
    //////////////////////////////////

    // Added DIVISOR
    // function testCanRedeemCollateralForDsc() public depositedCollateralAndMintedDsc {
    //     vm.startPrank(USER);
    //     dsc.approve(address(dsce), AMOUNT_TO_MINT);
    //     dsce.redeemCollateralForDsc(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
    //     vm.stopPrank();
    // (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(USER);
    // assertEq(totalDscMinted, 0);
    // }

    ////////////////////////
    // healthFactor Tests //
    ////////////////////////

    ///////////////////////
    // Liquidation Tests //
    ///////////////////////

    ///////////////////////////////////
    // View & Pure Function Tests //
    ///////////////////////////////////
}
