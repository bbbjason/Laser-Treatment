rm LASER.vvp
rm laser.vcd
iverilog -o LASER.vvp LASER.v tb.v
vvp LASER.vvp