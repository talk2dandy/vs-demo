DECLARE
    lv_out_arr      tbaadm.basp0099.ArrayType;
	V_SN			tbaadm.gam.WTAX_PCNT%type;
	v_dr_cr			tbaadm.gam.acid%type;
	v_acid			tbaadm.gam.acid%type;
    v_sol_id		tbaadm.gam.sol_id%type;
    v_gl_code		tbaadm.gsh.gl_code%type;
    v_ref_code		tbaadm.gsh.gl_sub_head_code%type;
    v_ref_desc		tbaadm.rct.ref_desc%type;
	v_sol_desc		tbaadm.rct.ref_desc%type;
	v_gl_sub_code	tbaadm.gam.gl_sub_head_code%type;
    v_crncy_code	tbaadm.gsh.crncy_code%type;
	v_grp			tbaadm.gsh.gl_sub_head_desc%type;
	v_m				tbaadm.gsh.gl_sub_head_desc%type;
	v_foracid		tbaadm.gam.foracid%type;
	v_acct_name		tbaadm.gam.acct_name%type;
	v_tran_date_bal	tbaadm.eab.TRAN_DATE_BAL%type;
	v_schm_type     tbaadm.gam.schm_type%type;
	v_Cbal          tbaadm.eab.TRAN_DATE_BAL%type;
	v_Dbal          tbaadm.eab.TRAN_DATE_BAL%type;
	v_acct_owntype  tbaadm.gam.acct_ownership%type;
	v_gl_sub_desc   tbaadm.gsh.gl_sub_head_desc%type;
	v_date			varchar2(10);
	v_balance		tbaadm.eab.TRAN_DATE_BAL%type;
	v_local_bal		tbaadm.eab.TRAN_DATE_BAL%type;
	v_dif_A_L 		tbaadm.eab.TRAN_DATE_BAL%type;
	v_Abal			tbaadm.eab.TRAN_DATE_BAL%type;
	v_Lbal			tbaadm.eab.TRAN_DATE_BAL%type;
    v_dif_I_E		tbaadm.eab.TRAN_DATE_BAL%type;
	v_Ibal 			tbaadm.eab.TRAN_DATE_BAL%type;
	v_Ebal			tbaadm.eab.TRAN_DATE_BAL%type;
	v_clsbal		tbaadm.eab.TRAN_DATE_BAL%type;
	v_eod_date		varchar2(10);
	loc_in_sol		varchar2(10);
    loc_in_date     varchar2(10);
	out_retCode		NUMBER;

	CURSOR GetDetails(loc_in_date varchar2, loc_in_sol varchar2)
	IS
	select
		g.acid,
		g.sol_id,
		g.acct_crncy_code,
		g.gl_sub_head_code,
		g.foracid,
		g.acct_name,
		g.acct_ownership,
		g.schm_type,
		nvl((eb.tran_date_bal),0),
		(nvl((eb.tran_date_bal),0) * CUSTOM.AmountToFC('NOR', to_date(loc_in_date,'DD_MM_YYYY'), g.acct_crncy_code, 'NGN'))
	from 
		tbaadm.gam g,tbaadm.eab eb
	where
		g.acid = eb.acid 
		and  eb.eod_date <= (to_date(loc_in_date, 'DD-MM-YYYY')) and end_eod_date>=(to_date(loc_in_date, 'DD-MM-YYYY'))
		and  g.sol_id in (select sol_id from tbaadm.sst where set_id = upper(loc_in_sol))
		and  g.del_flg  = 'N'
	order by g.gl_sub_head_code;
BEGIN
	out_retCode := 0;

	loc_in_date := '28-FEB-2018'
	loc_in_sol  := '143'
	OPEN GetDetails(loc_in_date,loc_in_sol);

	FETCH GetDetails into
		v_acid,
		v_sol_id,
		v_crncy_code,
		v_gl_sub_code,
		v_foracid,
		v_acct_name,
		v_acct_owntype,
		v_schm_type,
		v_balance,
		v_local_bal;

	if(GetDetails%notfound) then
		out_retCode := 1;
		close GetDetails;
		return;
	end if;
		
----Get Branch
	Begin
		select sol_desc into v_sol_desc
		from tbaadm.sol where sol_id = v_sol_id;
	exception
		when no_data_found then
			v_sol_desc:=null;
	End;

-----Get GL Description
	Begin
		select gsh.gl_code,gsh.gl_sub_head_desc
		into v_ref_code,v_gl_sub_desc
		from tbaadm.gsh 
		where sol_id = v_sol_id
		and gl_sub_head_code = v_gl_sub_code
		and crncy_code = v_crncy_code;
	 exception
		when no_data_found then
			v_ref_code:= null;
			v_gl_sub_desc := null;
	End;

---Categories
	if (v_gl_sub_code between '10000' and '28999') then
		v_grp:='A';
		v_m := 'M';
	end if;

	if (v_gl_sub_code between '30000' and '49999') then
		v_grp:='B';
		v_m := 'M';
	end if;

	if (v_gl_sub_code between '50000' and '75999') then
		v_grp :='B';
		v_m   :='M';
		v_ref_code  :='47';
		v_crncy_code :='';
		v_gl_sub_code :='47200';
		v_gl_sub_desc :=substr('CURRENT YR PROFIT/LOSS',1,50);
		v_foracid :='';
		v_acct_name :='';
		v_acct_owntype :='';
		v_schm_type :='';
	end if;

	if (v_gl_sub_code between '80000' and '89999') then
		v_grp:='C';
		v_m := 'M';
	end if;

	if (v_gl_sub_code between '90000' and '99999') then
		v_grp:='D';
		v_m := 'M';
	end if;

	if v_acct_owntype != 'O' then 
		if v_schm_type = 'ODA' then
			if v_local_bal >= 0 then
				if v_gl_sub_code = '15105' then
					v_grp := 'B';
					v_ref_code := '30';
					v_ref_desc := 'DEMAND-INDIVIDUAL';
					v_gl_sub_desc := 'DEMAND-INDIVIDUAL';
					v_gl_sub_code := '30100';
				else if v_gl_sub_code = '15100' then
					v_grp := 'B';
					v_ref_code := '30';
					v_ref_desc := 'DEMAND -CORPORATE';
					v_gl_sub_desc := 'DEMAND -CORPORATE';
					v_gl_sub_code := '30115';
				Else If v_gl_sub_code = '15605' Then
					v_grp := 'B';
					v_ref_code := '30';
					v_ref_desc := 'DEMAND - EXSTAFF';
					v_gl_sub_desc := 'DEMAND - EXSTAFF';
					v_gl_sub_code := '30130';
				Else If v_gl_sub_code = '15195' Then
					v_grp := 'B';
					v_ref_code := '30';
					v_ref_desc := 'DEMAND - VISA IND';
					v_gl_sub_desc := 'DEMAND - VISA IND';
					v_gl_sub_code := '31147';
				Else If v_gl_sub_code = '15200' Then
					v_grp := 'B';
					v_ref_code := '30';
					v_ref_desc := 'DEMAND - VISA NONIND';
					v_gl_sub_desc := 'DEMAND - VISA NONIND';
					v_gl_sub_code := '31149';
				End If;
			End If;
		End If;
	end if;

	if v_acct_owntype != 'O' then 
		if v_schm_type = 'ODA' then
			if v_local_bal < 0 then
				if v_gl_sub_code = '30100' then
					v_grp := 'A';
					v_ref_code := '15';
					v_ref_desc := 'OVERDRAFT-INDIVIDUAL A/C';
					v_gl_sub_code := '15105';
					v_gl_sub_desc := 'OVERDRAFT-INDIVIDUAL A/C';
				end if;
				if v_gl_sub_code  = '30105' then
					v_grp := 'A';
					v_ref_code := '15';
					v_ref_desc := 'OVERDRAFT-INDIVIDUAL A/C';
					v_gl_sub_desc := 'OVERDRAFT-INDIVIDUAL A/C';
					v_gl_sub_code := '15105';
				end if;
				if v_gl_sub_code  = '30135' then
					v_grp := 'A';
					v_ref_code := '15';
					v_ref_desc := 'OVERDRAFT-INDIVIDUAL A/C';
					v_gl_sub_desc := 'OVERDRAFT-INDIVIDUAL A/C';
					v_gl_sub_code := '15105';
				end if;

				--added 03-01-2012
				if v_gl_sub_code  = '30125' then
					v_grp := 'A';
					v_ref_code := '15';
					v_ref_desc := 'OVERDRAFT-INDIVIDUAL A/C';
					v_gl_sub_desc := 'OVERDRAFT-INDIVIDUAL A/C';
					v_gl_sub_code := '15105';
				end if;

				if v_gl_sub_code  = '30115' then
					v_grp := 'A';
					v_ref_code := '15';
					v_ref_desc := 'OVERDRAFT-CORPORATE A/C';
					v_gl_sub_desc := 'OVERDRAFT-CORPORATE A/C';
					v_gl_sub_code := '15100';
				end if;

				if v_gl_sub_code  = '30120' then
					v_grp := 'A';
					v_ref_code := '15';
					v_ref_desc := 'OVERDRAFT-CORPORATE A/C';
					v_gl_sub_desc := 'OVERDRAFT-CORPORATE A/C';
					v_gl_sub_code := '15100';
				end if;
					
				if v_gl_sub_code  = '30130' then
					v_grp := 'A';
					v_ref_code := '15';
					v_ref_desc := 'OVERDRAFT-EXSTAFF A/C';
					v_gl_sub_desc := 'OVERDRAFT-EXSTAFF A/C';
					v_gl_sub_code := '15605';
				End If;

				if v_gl_sub_code  = '31147' then
					v_grp := 'A';
					v_ref_code := '15';
					v_ref_desc := 'OVERDRAFT-VISA DEP IND A/C';
					v_gl_sub_desc := 'OVERDRAFT-VISA DEP IND A/C';
					v_gl_sub_code := '15195';
				End If;

				if v_gl_sub_code  = '31149' then
					v_grp := 'A';
					v_ref_code := '15';
					v_ref_desc := 'OVERDRAFT-VISA DEP NON-IND A/C';
					v_gl_sub_desc := 'OVERDRAFT-VISA DEP NON-IND A/C';
					v_gl_sub_code := '15200';
				end if;
			end if;
		end if;
	end if;
	
	if v_grp = 'A' then
		v_Abal := v_local_bal;
		v_Lbal := 0;
		v_Ibal := 0;
		v_Ebal := 0;
		v_Cbal := 0;
		v_Dbal := 0;
	end if;

	if v_grp = 'B' then
		v_Lbal := v_local_bal;
		v_Abal := 0;
		v_Ibal := 0;
		v_Ebal := 0;
		v_Cbal := 0;
		v_Dbal := 0;
	end if;

	if v_grp = 'C' then
		v_Cbal := v_local_bal;
		v_Lbal := 0;
		v_Abal := 0;
		v_Ibal := 0;
		v_Ebal := 0;
	end if;

	if v_grp = 'D' then
		v_Dbal := v_local_bal;
		v_Cbal := 0;
		v_Lbal := 0;
		v_Abal := 0;
		v_Ibal := 0;
		v_Ebal := 0;
	end if;


	--	v_eod_date := loc_in_date;

	v_eod_date := to_char(to_date(loc_in_date ,'DD-MM-RRRR'),'DD-MM-YYYY');  

	--	v_sol_id := loc_in_sol;

	out_rec :=      
		v_grp||'|'||
		v_m||'|'||
		v_ref_code||'|'||
		v_sol_desc||'|'||
		v_sol_id||'|'||
		v_crncy_code||'|'||
		v_gl_sub_code||'|'||
		v_gl_sub_desc||'|'||	
		v_balance||'|'||
		v_local_bal||'|'||
		v_eod_date||'|'||  
	--	v_sol_id||'|'||
		v_Abal||'|'||
		v_Lbal||'|'||
		0||'|'||
		v_Cbal||'|'||
		v_Dbal;
	DBMS_OUTPUT.PUT_LINE(out_rec);
END
/
