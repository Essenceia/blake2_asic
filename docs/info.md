<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->
# Blake2s RTL implementation

Implementation of the Blake2 cryptographic hash function (RFC7693) in synthesizable RTL.
This is a fully featured blake2s implementation supporting both block streaming and proving the secret key.

This implementation was designed with area and performance in mind, but area being the stronger priorative.

