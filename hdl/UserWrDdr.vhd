----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
-- Filename     UserWrDdr.vhd
-- Title        Top
--
-- Company      Design Gateway Co., Ltd.
-- Project      DDCamp
-- PJ No.       
-- Syntax       VHDL
-- Note         

-- Version      1.00
-- Author       B.Attapon
-- Date         2017/12/20
-- Remark       New Creation
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

Entity UserWrDdr Is
	Port
	(
		RstB			: in	std_logic;							-- use push button Key0 (active low)
		Clk				: in	std_logic;							-- clock input 100 MHz

		-- WrCtrl I/F
		MemInitDone		: in	std_logic;
		MtDdrWrReq		: out	std_logic;
		MtDdrWrBusy		: in	std_logic;
		MtDdrWrAddr		: out	std_logic_vector( 28 downto 7 );
		
		-- T2UWrFf I/F
		T2UWrFfRdEn		: out	std_logic;
		T2UWrFfRdData	: in	std_logic_vector( 63 downto 0 );
		T2UWrFfRdCnt	: in	std_logic_vector( 15 downto 0 );
		
		-- UWr2DFf I/F
		UWr2DFfRdEn		: in	std_logic;
		UWr2DFfRdData	: out	std_logic_vector( 63 downto 0 );
		UWr2DFfRdCnt	: out	std_logic_vector( 15 downto 0 )
	);
End Entity UserWrDdr;

Architecture rtl Of UserWrDdr Is

----------------------------------------------------------------------------------
-- Component declaration
----------------------------------------------------------------------------------
	
	
----------------------------------------------------------------------------------
-- Signal declaration
----------------------------------------------------------------------------------
	type	Stank_State		is
							(
								stIdle 		,
								stWaitFiFo	,
								stSendReq	,
								stSendData
							);
	signal	rState			: Stank_State;
	signal	rMemInitDone	: std_logic_vector( 1 downto 0 );
	signal 	rMtDdrWrReq		: std_logic;
	signal	rMtDdrWrAddr		: std_logic_vector( 26 downto 7 );
	signal  rStankAddress		: std_logic_vector(3 downto 0 );
	
	constant Lnw_aom : integer := 24575;
Begin

----------------------------------------------------------------------------------
-- Output assignment
----------------------------------------------------------------------------------
	MtDdrWrReq	<= rMtDdrWrReq;
	MtDdrWrAddr	<= rStankAddress(1 downto 0)&rMtDdrWrAddr(26 downto 7);
	
	T2UWrFfRdEn	<= UWr2DFfRdEn;
	UWr2DFfRdData	<= T2UWrFfRdData;
	UWr2DFfRdCnt	<= T2UWrFfRdCnt;
----------------------------------------------------------------------------------
-- DFF 
----------------------------------------------------------------------------------

	
	u_rMemInitDone : Process (Clk) Is
	Begin
		if ( rising_edge(Clk) ) then
			if ( RstB='0' ) then
				rMemInitDone	<= "00";
			else
				-- Use rMemInitDone(1) in your design
				rMemInitDone	<= rMemInitDone(0) & MemInitDone;
			end if;
		end if;
	End Process u_rMemInitDone;
	
	u_rState	: Process(Clk) Is
	Begin
		if( rising_edge(Clk) ) then
			if( RstB='0' ) then
				rState	<= stIdle;
			else 
				case( rState ) is
					when stIdle 	=>
						if( rMemInitDone(1)='1' ) then
							rState	<= stWaitFiFo;
						else
							rState	<= stIdle;
						end if;
					when stWaitFiFo =>
						if( T2UWrFfRdCnt>="00000000"&"01000000" ) then --T2UWrFfRdCnt more than 64 or equal 64
							rState	<= stSendReq;
						else
							rState	<= stWaitFiFo;
						end if;
					when stSendReq	=>
						if( MtDdrWrBusy='1' ) then
							rState	<= stSendData;
						else
							rState	<= stSendReq;
						end if;
					when stSendData	=>
						if( 
							rStankAddress="0011" and
							rMtDdrWrAddr( 26 downto 7 )=conv_std_logic_vector(Lnw_aom,20) 
						) then
							rState	<= stIdle;
						elsif( MtDdrWrBusy='0' ) then
							rState	<= stWaitFiFo;
						else
							rState	<= stSendData;
						end if;
				end case;
			end if;
		end if;
	End Process	u_rState;
	
	u_rMtDdrWrReq	: Process(Clk) Is
	Begin
		if( rising_edge(Clk) ) then
			if( RstB='0' ) then
				rMtDdrWrReq	<= '0';
			else
				if( rState=stSendReq and MtDdrWrBusy='0') then
					rMtDdrWrReq	<= '1';
				else
					rMtDdrWrReq	<= '0';
				end if;
			end if;
		end if;
	End Process u_rMtDdrWrReq;
	
	u_rStankAddress	: Process(Clk) Is
	Begin
		if( rising_edge(Clk) )then
			if( RstB='0' ) then
				rStankAddress	<= "0000";
			else
				if(
					rState=stSendData and 
					MtDdrWrBusy='0' and
					rMtDdrWrAddr( 26 downto 7 )=conv_std_logic_vector(Lnw_aom,20)
				  ) then
					rStankAddress	<= rStankAddress+1;
				else
					rStankAddress	<= rStankAddress;
				end if;
			end if;
		end if;
	End Process	u_rStankAddress;
	
	u_rMtDdrWrAddr	: Process(Clk) Is
	Begin
		if( rising_edge(Clk) )then
			if( RstB='0' )then
				rMtDdrWrAddr( 26 downto 7 )	<= (others=>'0');
			else
				if( 
					rState=stSendData and 
					MtDdrWrBusy='0' and 
					rMtDdrWrAddr( 26 downto 7 )=conv_std_logic_vector(Lnw_aom,20) 
				  )then
					rMtDdrWrAddr( 26 downto 7 )	<= (others=>'0');
				elsif(rState=stSendData and MtDdrWrBusy='0')then
					rMtDdrWrAddr( 26 downto 7 )	<= rMtDdrWrAddr( 26 downto 7 )+1;					
				else
					rMtDdrWrAddr( 26 downto 7 )	<= rMtDdrWrAddr( 26 downto 7 );
				end if;
			end if;
		end if;
	End Process	u_rMtDdrWrAddr;
	

End Architecture rtl;