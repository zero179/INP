-- cpu.vhd: Simple 8-bit CPU (BrainF*ck interpreter)
-- Copyright (C) 2019 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): xfenko01
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

-- ----------------------------------------------------------------------------
--                        Entity declaration
-- ----------------------------------------------------------------------------
entity cpu is
 port (
   CLK   : in std_logic;  -- hodinovy signal
   RESET : in std_logic;  -- asynchronni reset procesoru
   EN    : in std_logic;  -- povoleni cinnosti procesoru
 
   -- synchronni pamet RAM
   DATA_ADDR  : out std_logic_vector(12 downto 0); -- adresa do pameti
   DATA_WDATA : out std_logic_vector(7 downto 0); -- mem[DATA_ADDR] <- DATA_WDATA pokud DATA_EN='1'
   DATA_RDATA : in std_logic_vector(7 downto 0);  -- DATA_RDATA <- ram[DATA_ADDR] pokud DATA_EN='1'
   DATA_RDWR  : out std_logic;                    -- cteni (0) / zapis (1)
   DATA_EN    : out std_logic;                    -- povoleni cinnosti
   
   -- vstupni port
   IN_DATA   : in std_logic_vector(7 downto 0);   -- IN_DATA <- stav klavesnice pokud IN_VLD='1' a IN_REQ='1'
   IN_VLD    : in std_logic;                      -- data platna
   IN_REQ    : out std_logic;                     -- pozadavek na vstup data
   
   -- vystupni port
   OUT_DATA : out  std_logic_vector(7 downto 0);  -- zapisovana data
   OUT_BUSY : in std_logic;                       -- LCD je zaneprazdnen (1), nelze zapisovat
   OUT_WE   : out std_logic                       -- LCD <- OUT_DATA pokud OUT_WE='1' a OUT_BUSY='0'
 );
end cpu;


-- ----------------------------------------------------------------------------
--                      Architecture declaration
-- ----------------------------------------------------------------------------
architecture behavioral of cpu is
    signal ptr: std_logic_vector(12 downto 0);
	  signal ptr_inc: std_logic;
	  signal ptr_dec: std_logic;
	  signal pc: std_logic_vector(12 downto 0);
	  signal pc_inc: std_logic;
	  signal pc_dec: std_logic;
	  signal mx1: std_logic;
	  signal mx2: std_logic;
	  signal mx3: std_logic_vector(1 downto 0);
	  signal mx2_out: std_logic_vector(12 downto 0);
    signal cnt: std_logic_vector(7 downto 0);
    signal cnt_inc: std_logic;
    signal cnt_dec: std_logic;
 
    type fsm_state is(
        state_fetch,
        s_ptr_inc,
        s_ptr_dec,
        s_mem_inc,
        s_mem_dec,
        s_print,
        s_loading,
        s_halt,
        s_mem_inc_next,
        s_print_next,
        s_loading_next,
        s_mem_dec_next,
        state_decode,
        s_ignore,
        s_into_tmp_next,
        s_into_tmp,
        s_from_tmp,
        s_from_tmp_next,
        s_while1,
        s_while2,
        s_while_next1,
        s_while_next2,
        s_while_next3,
        s_while2_next1,
        s_while2_next2,
        s_while2_next3
    );
    signal state_next:fsm_state;
    signal state_now:fsm_state;
 
begin
    multiplexor1:process(pc, mx2_out, mx1)
	  begin
	      case(mx1) is 
	          when '0' => DATA_ADDR <= pc;
	          when '1' => DATA_ADDR <= mx2_out;
	          when others => NULL;
	      end case;
	  end process;

    multiplexor2:process(ptr, mx2_out, mx2)
	  begin
	      case(mx2) is
	          when '0' => mx2_out <= ptr;
	          when '1' => mx2_out <= "1000000000000";
	          when others => NULL;
	      end case;
	  end process;
    
    multiplexor3:process(IN_DATA, DATA_RDATA, mx3)
	  begin 
	      case(mx3) is
            	  when "00" => DATA_WDATA <= IN_DATA;
	          when "01" => DATA_WDATA <= DATA_RDATA-1;
	          when "10" => DATA_WDATA <= DATA_RDATA+1;
           	  when "11" => DATA_WDATA <= DATA_RDATA;
	          when others => NULL;
              end case;
    end process; 

    proc_pc:process(CLK, RESET)
	  begin
	      if(RESET = '1') then
		        pc <= "0000000000000";
	      elsif(CLK'event and CLK= '1') then
	          if(pc_inc = '1') then
  		          pc <= pc+1;
	          elsif(pc_dec = '1') then
		            pc <= pc-1;
	          end if;
	      end if;
	  end process;
 
    proc_ptr:process(CLK, RESET)
	  begin
	      if(RESET = '1') then 
		        ptr <= "1000000000000";
	      elsif(CLK'event) and (CLK = '1') then
	          if(ptr_inc = '1') then
		            ptr <= ptr+1;
	          elsif(ptr_dec = '1') then
	              ptr<= ptr-1;
	          end if;	
	      end if;
	  end process;

    proc_cnt: process(CLK,RESET)
    begin
        if (RESET = '1') then
            cnt <= X"00";
		    elsif (CLK'event) and (CLK = '1') then
			      if(cnt_inc = '0' and cnt_dec = '1') then
				        cnt <= cnt - 1;
			      elsif( cnt_inc = '1' and cnt_dec = '0') then
				        cnt <= cnt + 1;
			      end if;
		    end if;
	  end process;

    proc_state: process(RESET, CLK)
    begin
	      if (RESET = '1') then
		        state_now <= state_fetch;
	      elsif (CLK'event) and (CLK = '1') then
		       if (EN = '1') then
			          state_now <= state_next;
		       end if;
	      end if;
    end process;

    proc_fsm: process(state_now, DATA_RDATA, OUT_BUSY)
    begin 
        ptr_inc <= '0';
        ptr_dec <= '0';
        pc_dec <= '0';
        pc_inc<= '0';
        DATA_EN <= '0';
        OUT_WE<= '0';
        IN_REQ<= '0';
        cnt_inc<='0';
        cnt_dec<='0';

        case state_now is 
            when state_fetch =>
                mx1<='0';
                mx3<="11";
                DATA_EN<='1';
                DATA_RDWR<='0';
                state_next<=state_decode;

            when state_decode=>
                case (DATA_RDATA) is
                    when X"3E" => state_next <= s_ptr_inc;
                    when X"3C" => state_next <= s_ptr_dec;
                    when X"2B" => state_next <= s_mem_inc;
                    when X"2D" => state_next <= s_mem_dec;
                    when X"2E" => state_next <= s_print;
                    when X"2C" => state_next <= s_loading;
                    when X"00" => state_next <= s_halt;
                    when X"24" => state_next <= s_into_tmp;
                    when X"21" => state_next <= s_from_tmp;
                    when X"5B" => state_next <= s_while1;
			              when X"5D" => state_next <= s_while2;
                    when others=> state_next <= s_ignore;
                end case;

            when s_ptr_inc =>
                ptr_inc <= '1';
                pc_inc <= '1';
                state_next <= state_fetch;

            when s_ptr_dec =>
                ptr_dec <= '1';
                pc_inc <= '1';
                state_next <= state_fetch;

            when s_mem_inc=>
                mx1 <= '1';
                mx2 <= '0';
                mx3 <= "10";
                DATA_EN <= '1';
                DATA_RDWR <= '0';
                state_next <= s_mem_inc_next;

            when s_mem_inc_next =>
                mx1 <= '1';
                mx2 <= '0';
                mx3 <= "10";
                DATA_EN <= '1';
                DATA_RDWR <= '1';
                pc_inc <= '1';
                state_next <= state_fetch;

            when s_mem_dec =>
                mx1<= '1';
                mx2<= '0';
                mx3<= "01";
                DATA_RDWR<='0';
                DATA_EN<='1';
                state_next <= s_mem_dec_next;

            when s_mem_dec_next =>
                mx1<= '1';
                mx2<= '0';
                mx3<= "01";
                DATA_RDWR<='1';
                DATA_EN<='1';
                pc_inc<= '1';
                state_next <= state_fetch;

            when s_print=>
                mx1 <= '1';
                mx2 <= '0';
                mx3 <= "11";
                DATA_EN <= '1';
                DATA_RDWR<= '0';
                state_next <= s_print_next;

            when s_print_next=>
                if (OUT_BUSY = '1')then
                    state_next<= s_print_next;
                else
                    OUT_DATA <= DATA_RDATA;
                    OUT_WE <= '1';
                    pc_inc <='1';
                    state_next <= state_fetch;
                end if;

            when s_loading => 
                IN_REQ <= '1';
                state_next <= s_loading_next;

            when s_loading_next=>
                if(IN_VLD = '0')then 
                    state_next<= s_loading_next;
                else
                    mx1 <= '1';
                    mx2 <= '0';
                    mx3 <= "00";
                    DATA_EN <= '1';
                    DATA_RDWR <= '1';
                    pc_inc <= '1';
                    state_next <= state_fetch;
                end if;
            
            when s_into_tmp=>
                mx1<='1';
                mx2<='0';
                mx3<="11";
                DATA_EN<= '1';
                DATA_RDWR<= '0';
                state_next <= s_into_tmp_next;

            when s_into_tmp_next=>
                mx1<='1';
                mx2<='1';
                mx3<="11";
                DATA_EN<= '1';
                DATA_RDWR<= '1';
                pc_inc<= '1';
                state_next<=state_fetch;

            when s_from_tmp=>
                mx1<='1';
                mx2<='1';
                mx3<="11";
                DATA_EN<= '1';
                DATA_RDWR<= '0';
                state_next <= s_from_tmp_next;

            when s_from_tmp_next=>
                mx1<='1';
                mx2<='0';
                mx3<="11";
                DATA_EN<= '1';
                DATA_RDWR<= '1';
                pc_inc<='1';
                state_next<= state_fetch;

            when s_while1=>
                mx1<='1';
                mx2<='0';
                mx3<="11";
                DATA_EN<='1';
                DATA_RDWR<='0';
               -- pc_inc<= '1';
                state_next<=s_while_next1;

            when s_while_next1=>
                if (DATA_RDATA = X"00") then
                    cnt_inc<= '1';
                    pc_inc<='1';
                    state_next <= s_while_next2;
                else
                    pc_inc<='1';
                    state_next<= state_fetch;
                end if;

            when s_while_next2=>
			          mx1<='0';
                mx3<="11";
                DATA_EN<='1';
                DATA_RDWR<='0';
                state_next<=s_while_next3;
           
            when s_while_next3=>
                if (DATA_RDATA = X"5B")then
                    cnt_inc <='1';
                    pc_inc <='1';
                    state_next <= s_while_next2;
                elsif (DATA_RDATA = X"5D")then
                    if (cnt = X"01") then 
                        cnt_dec <= '1';
                        pc_inc <= '1';
                        state_next<= state_fetch;
                    else
                        cnt_dec<= '1';
                        pc_inc<= '1';
                        state_next<=s_while_next2;
                    end if;
                else
                    pc_inc<='1';
                    state_next<= s_while_next2;
                end if;

            when s_while2=>
                mx1<='1';
                mx2<='0';
                mx3<="11";
                DATA_EN<='1';
                DATA_RDWR<='0';
                state_next<=s_while2_next1;

            when s_while2_next1 =>
                if (DATA_RDATA = X"00") then
                    pc_inc<='1';
                    state_next<= state_fetch;
                else
                    cnt_inc<='1';
                    pc_dec<= '1';
                    state_next<=s_while2_next2;
                end if;

            when s_while2_next2=>
                mx1<='0';
                mx3<="11";
                DATA_EN<='1';
                DATA_RDWR<='0';
                state_next<=s_while2_next3;

            when s_while2_next3=>
                if (DATA_RDATA = X"5D") then
                    cnt_inc<='1';
                    pc_dec<='1';
                    state_next<= s_while2_next2;
                elsif (DATA_RDATA = X"5B") then
                    if (cnt = X"01") then 
                        cnt_dec<='1';
                        pc_inc<= '1';
                        state_next<= state_fetch;
                    else
                        cnt_dec<='1';
                        pc_dec<='1';
                        state_next<= s_while2_next2;
                    end if;
                else
                    pc_dec<='1';
                    state_next<= s_while2_next2;
                end if;


            when s_halt =>
				        state_next <= s_halt;

            when s_ignore=>
                pc_inc<='1';
                state_next<= state_fetch;
            when others=>
        end case;    
    end process;

 -- pri tvorbe kodu reflektujte rady ze cviceni INP, zejmena mejte na pameti, ze 
 --   - nelze z vice procesu ovladat stejny signal,
 --   - je vhodne mit jeden proces pro popis jedne hardwarove komponenty, protoze pak
 --   - u synchronnich komponent obsahuje sensitivity list pouze CLK a RESET a 
 --   - u kombinacnich komponent obsahuje sensitivity list vsechny ctene signaly.
 
end behavioral;





