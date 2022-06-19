// // SPDX-License-Identifier: GPL-3.0
// pragma solidity ^0.8.14;

// contract CodeRegex {
//     struct State {
//         bool accepts;
//         function(bytes memory) internal view func;
//     }

//     function matches(string memory input) internal returns (bool) {
//         State memory cur = State(false, s1);

//         for (uint256 i = 0; i < bytes(input).length; i++) {
//             bytes memory c = bytes(input)[i];

//             cur = cur.func(c);
//         }

//         return cur.accepts;
//     }

//     function s0(bytes1 c) internal view returns (State memory) {
//         c = c;
//         return State(false, s0);
//     }

//     function s1(bytes1 c) internal view returns (State memory) {
//         if (
//             c == 37 ||
//             c == 43 ||
//             c == 45 ||
//             c == 46 ||
//             (c >= 48 && c <= 57) ||
//             (c >= 65 && c <= 90) ||
//             c == 95 ||
//             (c >= 97 && c <= 122)
//         ) {
//             return State(false, s2);
//         }

//         return State(false, s0);
//     }

//     function s2(bytes1 c) internal view returns (State memory) {
//         if (
//             c == 37 ||
//             c == 43 ||
//             c == 45 ||
//             c == 46 ||
//             (c >= 48 && c <= 57) ||
//             (c >= 65 && c <= 90) ||
//             c == 95 ||
//             (c >= 97 && c <= 122)
//         ) {
//             return State(false, s3);
//         }
//         if (c == 64) {
//             return State(false, s4);
//         }

//         return State(false, s0);
//     }

//     function s3(bytes1 c) internal view returns (State memory) {
//         if (
//             c == 37 ||
//             c == 43 ||
//             c == 45 ||
//             c == 46 ||
//             (c >= 48 && c <= 57) ||
//             (c >= 65 && c <= 90) ||
//             c == 95 ||
//             (c >= 97 && c <= 122)
//         ) {
//             return State(false, s3);
//         }
//         if (c == 64) {
//             return State(false, s4);
//         }

//         return State(false, s0);
//     }

//     function s4(bytes1 c) internal view returns (State memory) {
//         if (
//             (c >= 46 && c <= 47) ||
//             (c >= 48 && c <= 57) ||
//             (c >= 58 && c <= 64) ||
//             (c >= 65 && c <= 90) ||
//             (c >= 91 && c <= 95) ||
//             (c >= 97 && c <= 122)
//         ) {
//             return State(false, s5);
//         }

//         return State(false, s0);
//     }

//     function s5(bytes1 c) internal view returns (State memory) {
//         if (c == 46) {
//             return State(false, s6);
//         }
//         if (
//             c == 47 ||
//             (c >= 48 && c <= 57) ||
//             (c >= 58 && c <= 64) ||
//             (c >= 65 && c <= 90) ||
//             (c >= 91 && c <= 95) ||
//             (c >= 97 && c <= 122)
//         ) {
//             return State(false, s7);
//         }

//         return State(false, s0);
//     }

//     function s6(bytes1 c) internal view returns (State memory) {
//         if (c == 46) {
//             return State(false, s6);
//         }
//         if (
//             c == 47 ||
//             (c >= 48 && c <= 57) ||
//             (c >= 58 && c <= 64) ||
//             (c >= 91 && c <= 95)
//         ) {
//             return State(false, s7);
//         }
//         if ((c >= 65 && c <= 90) || (c >= 97 && c <= 122)) {
//             return State(false, s8);
//         }

//         return State(false, s0);
//     }

//     function s7(bytes1 c) internal view returns (State memory) {
//         if (c == 46) {
//             return State(false, s6);
//         }
//         if (
//             c == 47 ||
//             (c >= 48 && c <= 57) ||
//             (c >= 58 && c <= 64) ||
//             (c >= 65 && c <= 90) ||
//             (c >= 91 && c <= 95) ||
//             (c >= 97 && c <= 122)
//         ) {
//             return State(false, s7);
//         }

//         return State(false, s0);
//     }

//     function s8(bytes1 c) internal view returns (State memory) {
//         if (c == 46) {
//             return State(false, s6);
//         }
//         if (
//             c == 47 ||
//             (c >= 48 && c <= 57) ||
//             (c >= 58 && c <= 64) ||
//             (c >= 91 && c <= 95)
//         ) {
//             return State(false, s7);
//         }
//         if ((c >= 65 && c <= 90) || (c >= 97 && c <= 122)) {
//             return State(true, s9);
//         }

//         return State(false, s0);
//     }

//     function s9(bytes1 c) internal view returns (State memory) {
//         if (c == 46) {
//             return State(false, s6);
//         }
//         if (
//             c == 47 ||
//             (c >= 48 && c <= 57) ||
//             (c >= 58 && c <= 64) ||
//             (c >= 91 && c <= 95)
//         ) {
//             return State(false, s7);
//         }
//         if ((c >= 65 && c <= 90) || (c >= 97 && c <= 122)) {
//             return State(true, s10);
//         }

//         return State(false, s0);
//     }

//     function s10(bytes1 c) internal view returns (State memory) {
//         if (c == 46) {
//             return State(false, s6);
//         }
//         if (
//             c == 47 ||
//             (c >= 48 && c <= 57) ||
//             (c >= 58 && c <= 64) ||
//             (c >= 91 && c <= 95)
//         ) {
//             return State(false, s7);
//         }
//         if ((c >= 65 && c <= 90) || (c >= 97 && c <= 122)) {
//             return State(true, s10);
//         }

//         return State(false, s0);
//     }
// }
