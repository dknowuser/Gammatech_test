gammatech_test
==============

Description
===========
When the utility starts it waits for a new raw connection on port 23.
When it gets a "Connect" message from a host it starts ping-pong procedure:
* The device sends a "Ping" message and waits for a "Pong" message within 10s timeout.
* When ping-pong procedure is initiated the device sends device info (device name, OS version,
serial number and description) as an answer to a "Get" message.
If the utility gets "Break" message it breaks existing connection.

Build
=====
To build the utility just type following command in gammatech_test-1.0.0 directory:
```dpkg-buildpackage -uc -us```

A deb-package will appear in gammatech_test-1.0.0/.. directory.

Install
=======
To install the package:
```dpkg -i gammatech-test_1.0.0_*.deb```

Usage
=====
To start the utility type:
```systemctl start gammatech-test.service```

To stop the utility:
```systemctl stop gammatech-test.service```
