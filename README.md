# AES-128 Encryption in 8086 Assembly

A low-level implementation of the **AES-128 (Advanced Encryption Standard)** algorithm written entirely in **Intel 8086 Assembly Language**. This project demonstrates how complex cryptographic transformations—such as Galois Field multiplication and matrix manipulation—can be achieved in a 16-bit real-mode environment.

## 📖 Overview

This program accepts a 128-bit input (plaintext) from the user, processes it through the standard 10 rounds of AES encryption, and outputs the resulting ciphertext. It is optimized for the 8086 architecture, utilizing macros for the primary AES transformations to maintain code readability and modularity.

### Key Features

* **Full 128-bit Block Size:** Processes data in standard 16-byte blocks.
* **10-Round Encryption Loop:** Implements the standard AES round count.
* **Modular Macro Design:** `SubBytes`, `ShiftRows`, `MixColumns`, and `AddRoundKey` are implemented as distinct macros.
* **GF(2⁸) Arithmetic:** Custom implementation of Galois Field multiplication for the `MixColumns` step.
* **Matrix Transposition:** Handles conversion between standard row-major input and AES column-major state matrices.

---

## ⚙️ Technical Implementation

### Memory Model

The program uses the `.MODEL SMALL` directive, with separate Data (`.DATA`) and Code (`.CODE`) segments.

* **Input:** 32 Hexadecimal characters (parsed into 16 bytes).
* **State:** A 4x4 byte matrix (128 bits).
* **S-Box:** A static 256-byte substitution table stored in the data segment.

### The Transformations

The core logic is split into four macro operations:

1. **SubBytes:** Non-linear substitution using an S-Box lookup table.
2. **ShiftRows:** Cyclical byte shifting of the 4x4 State matrix rows.
* *Row 1:* No shift.
* *Row 2:* Rotate left by 1.
* *Row 3:* Rotate left by 2.
* *Row 4:* Rotate left by 3.


3. **MixColumns:** Matrix multiplication over Galois Field (2⁸).
* *Math:* Uses custom `mul2` (shift + conditional XOR `0x1B`) and `mul` macros to perform multiplication by 1, 2, and 3.


4. **AddRoundKey:** Simple XOR operation between the State and the Round Key.

### Input Handling

AES operates on a **Column-Major** matrix, but standard memory input is **Row-Major**.

* The code includes a custom `Transpose` procedure to flip the input matrix before processing and flip it back before printing.

---

## How to Input

1. Run the program.
2. The program expects exactly **32 Hexadecimal characters** (0-9, A-F).
3. These 32 characters represent the 16 bytes of your plaintext block.
* *Example:* Entering `00112233445566778899AABBCCDDEEFF` represents the byte sequence `00 11 22 33...`

---

## ⚠️ Current Limitations & Notes

* **Static Key:** Currently, the `ROUND_KEY` is statically defined in `.DATA` (initialized to `FF...`). The `AddRoundKey` step uses this single key for all rounds. A full AES implementation requires a **Key Schedule** algorithm to expand this initial key into 11 unique round keys.
* **Input Constraints:** The input routine strictly expects valid Hex characters. Error handling for non-hex input is minimal.

---

## License

This project is open-source and available under the **MIT License**.

```
