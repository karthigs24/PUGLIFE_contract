/*
created by: karthi
created at:08/11/21 
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

// contract PUGLIFE is ERC20 {
//     constructor() ERC20("PUGLIFE", "PUGL") {
//         _mint(msg.sender, 500000000000000 * (10**uint256(decimals())));
//     }
// }

contract PUGLIFE is Context, IERC20, IERC20Metadata, Ownable {
    using SafeMath for uint256;
    using Address for address;

    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => bool) private _isExcluded;
    address[] private _excluded;

    uint256 private constant MAX = ~uint256(0);
    uint256 private constant _tTotal = 500000000000000 * 10**18;
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _tFeeTotal;

    string private _name = "PUGLIFE";
    string private _symbol = "PUGL";
    uint8 private _decimals = 18;

    uint256 public taxFee = 2;
    uint256 private previousTaxFee = taxFee;

    uint256 public burnFee = 1;
    uint256 private previousBurnFee = burnFee;

    uint256 public devFee = 1;
    uint256 private previousDevFee = devFee;

    uint256 public liqudityFee = 5;
    uint256 private previousLiqudityFee = liqudityFee;

    bool public enableFee;

    uint256 private _amount_burnt;

    event FeeEnable(bool enableFee);
    event SetMaxTxPercent(uint256 maxPercent);
    event SetTaxFeePercent(uint256 taxFeePercent);
    event ExternalTokenTransfered(
        address externalAddress,
        address toAddress,
        uint256 amount
    );

    constructor() {
        _rOwned[_msgSender()] = _rTotal;
        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    function name() external view virtual override returns (string memory) {
        return _name;
    }

    function symbol() external view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() external view virtual override returns (uint8) {
        return _decimals;
    }

    function totalSupply() external view virtual override returns (uint256) {
        return _tTotal - _amount_burnt;
    }

    function balanceOf(address account)
        public
        view
        virtual
        override
        returns (uint256)
    {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount)
        external
        virtual
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender)
        external
        view
        virtual
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        external
        virtual
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(
            currentAllowance >= amount,
            "ERC20: transfer amount exceeds allowance"
        );
        _approve(sender, _msgSender(), currentAllowance - amount);

        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        external
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] + addedValue
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        external
        virtual
        returns (bool)
    {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(
            currentAllowance >= subtractedValue,
            "ERC20: decreased allowance below zero"
        );
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function totalFees() external view returns (uint256) {
        return _tFeeTotal;
    }

    function tokenFromReflection(uint256 rAmount)
        public
        view
        returns (uint256)
    {
        require(
            rAmount <= _rTotal,
            "Amount must be less than total reflections"
        );
        uint256 currentRate = getRate();
        return rAmount.div(currentRate);
    }

    function excludeFromReward(address account) public onlyOwner {
        require(!_isExcluded[account], "Account is already included");
        if (_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInReward(address account) public onlyOwner {
        require(_isExcluded[account], "Account is not excluded");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    function isExcludedFromReward(address account)
        external
        view
        returns (bool)
    {
        return _isExcluded[account];
    }

    function setTaxFeePercent(uint256 fee) external onlyOwner {
        taxFee = fee;
        emit SetTaxFeePercent(taxFee);
    }

    function setEnableFee(bool enableTax) external onlyOwner {
        enableFee = enableTax;
        emit FeeEnable(enableTax);
    }

    function takeReflectionFee(uint256 rFee, uint256 tFee) internal {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    function getTValues(uint256 amount)
        internal
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        uint256 tAmount = amount;
        uint256 tFee = calculateTaxFee(tAmount);
        uint256 tburnFee = calculateBurnFee(tAmount);
        uint256 tdevFee = calculateDevFee(tAmount);
        uint256 tliquidity = calculateLiquidityFee(tAmount);
        uint256 tTransferAmount = tAmount
            .sub(tFee)
            .sub(tburnFee)
            .sub(tdevFee)
            .sub(tliquidity);
        return (tTransferAmount, tFee, tburnFee, tdevFee, tliquidity);
    }

    function getRValues(
        uint256 amount,
        uint256 tFee,
        uint256 tburnFee,
        uint256 tdevFee,
        uint256 tliquidityFee
    )
        internal
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 currentRate = getRate();
        uint256 tAmount = amount;
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rburnFee = tburnFee.mul(currentRate);
        uint256 rdevFee = tdevFee.mul(currentRate);
        uint256 rliquidity = tliquidityFee.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee);
        return (rAmount, rTransferAmount, rFee);
    }

    function getRate() internal view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function getCurrentSupply() internal view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (
                _rOwned[_excluded[i]] > rSupply ||
                _tOwned[_excluded[i]] > tSupply
            ) return (_rTotal, _tTotal);
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function calculateTaxFee(uint256 _amount) internal view returns (uint256) {
        return _amount.mul(taxFee).div(10**2);
    }

    function calculateBurnFee(uint256 _amount) internal view returns (uint256) {
        return _amount.mul(burnFee).div(10**2);
    }

    function calculateDevFee(uint256 _amount) internal view returns (uint256) {
        return _amount.mul(devFee).div(10**2);
    }

    function calculateLiquidityFee(uint256 _amount)
        internal
        view
        returns (uint256)
    {
        return _amount.mul(liqudityFee).div(10**3);
    }

    function removeAllFee() internal {
        if (taxFee == 0) return;
        previousTaxFee = taxFee;
        taxFee = 0;
    }

    function restoreAllFee() internal {
        taxFee = previousTaxFee;
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        _beforeTokenTransfer(from, to);
        uint256 senderBalance = balanceOf(from);
        require(
            senderBalance >= amount,
            "ERC20: transfer amount exceeds balance"
        );
        bool takeFee = true;
        if (!enableFee) {
            takeFee = false;
        }
        _tokenTransfer(from, to, amount, takeFee);
    }

    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFee
    ) internal {
        if (!takeFee) removeAllFee();
        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }
        if (!takeFee) restoreAllFee();
    }

    function _transferStandard(
        address sender,
        address recipient,
        uint256 tAmount
    ) internal {
        (
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tburnFee,
            uint256 tdevFee,
            uint256 tliquidityFee
        ) = getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = getRValues(
            tAmount,
            tFee,
            tburnFee,
            tdevFee,
            tliquidityFee
        );
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        takeReflectionFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferBothExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) internal {
        (
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tburnFee,
            uint256 tdevFee,
            uint256 tliquidityFee
        ) = getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = getRValues(
            tAmount,
            tFee,
            tburnFee,
            tdevFee,
            tliquidityFee
        );
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        takeReflectionFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferToExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) internal {
        (
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tburnFee,
            uint256 tdevFee,
            uint256 tliquidityFee
        ) = getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = getRValues(
            tAmount,
            tFee,
            tburnFee,
            tdevFee,
            tliquidityFee
        );
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        takeReflectionFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferFromExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) internal {
        (
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tburnFee,
            uint256 tdevFee,
            uint256 tliquidityFee
        ) = getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = getRValues(
            tAmount,
            tFee,
            tburnFee,
            tdevFee,
            tliquidityFee
        );
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        takeReflectionFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function withdrawToken(address _tokenContract, uint256 _amount)
        external
        onlyOwner
    {
        require(_tokenContract != address(0), "Address cant be zero address");
        IERC20 tokenContract = IERC20(_tokenContract);
        tokenContract.transfer(msg.sender, _amount);
        emit ExternalTokenTransfered(_tokenContract, msg.sender, _amount);
    }

    function _beforeTokenTransfer(address from, address to) internal virtual {}
}