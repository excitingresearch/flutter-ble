# TODO esptool?
# TODO port param
# TODO fw ".ino.bin" param
# TODO erase flag
# python3 "/home/pibeeckm/.arduino15/packages/esp32/tools/esptool_py/4.5.1/esptool.py"
output=$(python3 "./tools/esptool.py" \
    --chip esp32c3 \
    --port "/dev/ttyACM0" \
    --baud 921600  \
    --before default_reset \
    --after hard_reset write_flash  -z \
    --flash_mode dio \
    --flash_freq 80m \
    --flash_size 4MB \
    0x0 "./fw-files/moody_v4_0_5_fw.ino.bootloader.bin" \
    0x8000 "./fw-files/moody_v4_0_5_fw.ino.partitions.bin" \
    0xe000 "/home/pibeeckm/.arduino15/packages/esp32/hardware/esp32/2.0.9/tools/partitions/boot_app0.bin" \
    0x10000 "./fw-files/moody_v4_0_5_fw.ino.bin")

filtered_output=$(echo "$output" | grep "MAC:")
# echo $filtered_output
mac_address=$(echo "$filtered_output" | awk '{print $2}' | sed 's/://g')
# echo $mac_address
# last_four_digits=$(echo "${mac_address^^}" | tail -c 5)
# echo "Device ID: MOODY_$last_four_digits"
# Error Handling
if [ -z "$mac_address" ]; then  # Check if mac_address is empty 
    echo "Error: Flashing failed" # Failed to retrieve MAC address. 
    echo $output
else
    echo $mac_address
    last_four_digits=$(echo "${mac_address^^}" | tail -c 5)
    echo "Success: Flashing OK" 
    echo "Device ID: MOODY_$last_four_digits"
fi