echo "[+] Creating Modbus dictionary..."
cat <<EOF > modbus.dict
"read_coils"="\x01"
"read_discrete"="\x02"
"read_holding"="\x03"
"read_input"="\x04"
"write_single_coil"="\x05"
"write_single_reg"="\x06"
"write_multiple_coils"="\x0F"
"write_multiple_regs"="\x10"
EOF
