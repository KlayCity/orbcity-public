// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

contract TokenHelper {
    function _balanceOf(address token, address account) internal view returns (uint256) {
        if (token == address(this)) {
            return account.balance;
        }

        (bool check, bytes memory data) = address(token).staticcall(abi.encodeWithSignature("balanceOf(address)", account));
        require(check == true, "[TokenHelper] _balanceOf");
        uint256 balance = abi.decode(data, (uint256));
        return balance;
    }

    function _transfer(
        address token,
        address to,
        uint256 amounts
    ) internal {
        /*bytes memory data*/

        if (token == address(this)) {
            payable(to).transfer(amounts);
            return;
        }

        (bool ret, ) = address(token).call(abi.encodeWithSignature("transfer(address,uint256)", to, amounts));
        require(ret == true, "[TokenHelper] transfer");
    }

    function _transferFrom(
        address token,
        address from,
        address to,
        uint256 amounts
    ) internal {
        /*bytes memory data*/
        (bool ret, ) = address(token).call(abi.encodeWithSignature("transferFrom(address,address,uint256)", from, to, amounts));
        require(ret == true, "[TokenHelper] transferFrom");
    }

    function _burnFrom(
        address token,
        address account,
        uint256 amounts
    ) internal {
        (bool ret, ) = address(token).call(abi.encodeWithSignature("burnFrom(address,uint256)", account, amounts));
        require(ret == true, "[TokenHelper] brunFrom");
    }

    function _burn(address token, uint256 amounts) internal {
        (bool ret, ) = address(token).call(abi.encodeWithSignature("burn(uint256)", amounts));
        require(ret == true, "[TokenHelper] brun");
    }
}
