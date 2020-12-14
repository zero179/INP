-- Autor reseni: SIMON FENKO, xfenko01

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity ledc8x8 is
port ( 
	RESET, SMCLK : in std_logic;
	ROW, LED : out std_logic_vector(7 downto 0)
);
end ledc8x8;

architecture main of ledc8x8 is

	signal ctr_row: std_logic_vector(0 to 7):= "10000000";
	signal ctr_led: std_logic_vector(0 to 7):= (others => '1');
	signal reader: std_logic;
	signal ctr_reader: std_logic_vector(11 downto 0) := (others => '0') ;
	signal changer: std_logic_vector(0 to 21) := (others => '0');
	signal state: std_logic_vector (1 downto 0) := "00";
begin
	--Reader
	reader1: process(SMCLK, RESET)
	begin
		
		if RESET = '1' then
			ctr_reader <= "000000000000";
		elsif rising_edge(SMCLK) then
			ctr_reader <= ctr_reader + 1;
		end if;
	end process reader1;
   reader <= '1' when ctr_reader = X"FF" else '0';

	changer1: process(SMCLK, RESET) 
	begin
      	if RESET = '1'then
          changer <= (others => '0');
      	elsif rising_edge(SMCLK) then 
      		changer <= changer + 1;
				if changer = "1110000100000000000000" and state /= "10" then
              	state <= state + 1;
      			changer <= (others => '0');
    end if;
	 end if;
	 end process changer1;
	
	
	-- Rotacia
	rotation: process(SMCLK, RESET, reader)
	begin
		
		if RESET = '1' then
			ctr_row <= "10000000";
		elsif SMCLK'event and SMCLK = '1' then
			if reader = '1' then
				ctr_row <= ctr_row(7) & ctr_row(0 to 6);
		end if;
		end if;
		
	end process rotation;
	ROW <= ctr_row;
	-- Dekoder
	decoder1: process(ctr_row)
	begin
		if state = "00" then 
		case(ctr_row) is
		when "10000000" =>
			ctr_led <= "11101111";
		when "01000000" =>
			ctr_led <= "11101000";
		when "00100000" =>
			ctr_led <= "11100111";
		when "00010000" =>
			ctr_led <= "00000111";
		when "00001000" =>
			ctr_led <= "11101001";
		when "00000100" =>
			ctr_led <= "11101110";
		when "00000010" =>
			ctr_led <= "00001110";
		when "00000001" =>
			ctr_led <= "11110001";
		when others =>
			ctr_led <= "11111111";
		end case;
		 
      elsif state = "01" then
		case(ctr_row) is
		when "10000000" =>
			ctr_led <= "11111111";
		when "01000000" =>
			ctr_led <= "11111111";
		when "00100000" =>
			ctr_led <= "11111111";
		when "00010000" =>
			ctr_led <= "11111111";
		when "00001000" =>
			ctr_led <= "11111111";
		when "00000100" =>
			ctr_led <= "11111111";
		when "00000010" =>
			ctr_led <= "11111111";
		when "00000001" =>
			ctr_led <= "11111111";
		when others =>
			ctr_led <= "11111111";
		end case;  
      
		elsif state = "10" then
		case(ctr_row) is
		when "10000000" =>
			ctr_led <= "11101111";
		when "01000000" =>
			ctr_led <= "11101000";
		when "00100000" =>
			ctr_led <= "11100111";
		when "00010000" =>
			ctr_led <= "00000111";
		when "00001000" =>
			ctr_led <= "11101001";
		when "00000100" =>
			ctr_led <= "11101110";
		when "00000010" =>
			ctr_led <= "00001110";
		when "00000001" =>
			ctr_led <= "11110001";
		when others =>
			ctr_led <= "11111111";
		end case;

		end if;

		
	end process decoder1;

	
	LED <= ctr_led;
	
end main;