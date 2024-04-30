MODULE MainModule

    !***********************************************************
    !
    ! Module:  MainModule
    ! Description:
    !   This program simulated a palletizer robot system which consists of ABB IRB 660 Robot, 
    !   2 Input Station, 1 Input Pallet Station, and 5 output pallet bays. Along with the PLC 
    !   system, the robot will handle 9 Product SKU with 1 stacking pattern each.
    !   
    ! Author: IDJOSYE
    ! Version: 1.0
    !
    !***********************************************************
    

    PROC main()
        !### Setup Section ###
        
        Cycle_Setup;
        Initial_Arm_Move_Up;
        Tool_Home_Check;
        Check_Pressure;
        
        !### Loop Section ###
        Repeat:
        
        IF DI30_Master_Cycle_On=0 then
            !*** Master Conveyor Stopped, CYCLE STOP
            TPWrite("Main Conveyor Stop, Robot Stopping!");
        ELSEIF DI31_Air_Pressure_Supply=0 THEN
            !*** Robot Air Pressure Supply Low, CYCLE STOP 
            TPWrite("Robot Air Supply Low, Robot Stopping!");
        ELSE
            !*** All good, CYCLE START
            
            mxStatus:=
                [[nBox_Pattern_Bay1, nBox_Pattern_Bay2, nBox_Pattern_Bay3, nBox_Pattern_Bay4, nBox_Pattern_Bay5],
                 [nBox_Count_Bay1,   nBox_Count_Bay2,   nBox_Count_Bay3,   nBox_Count_Bay4,   nBox_Count_Bay5  ],
                 [nBox_Layer_Bay1,   nBox_Layer_Bay2,   nBox_Layer_Bay3,   nBox_Layer_Bay4,   nBox_Layer_Bay5  ]];
                 
            arPallet_Present:=
                [DI16_Bay1_Pallet_Pres, DI17_Bay2_Pallet_Pres, DI18_Bay3_Pallet_Pres, DI19_Bay4_Pallet_Pres, DI16_Bay1_Pallet_Pres];
            
            !*** (1) Scanning for force discharge signal
            mxDischarge_Signal:=
                [[DI11_Bay1_Force_Disc, DI12_Bay2_Force_Disc, DI13_Bay3_Force_Disc, DI14_Bay4_Force_Disc, DI15_Bay5_Force_Disc ],  
                 [dioBay1_Pallet_Full,  dioBay2_Pallet_Full,  dioBay3_Pallet_Full,  dioBay4_Pallet_Full,  dioBay5_Pallet_Full  ]];

            mxPLC_Dicharge:=
                [[DO06_Bay1_Pallet_Full,     DO07_Bay2_Pallet_Full,     DO08_Bay3_Pallet_Full,     DO09_Bay4_Pallet_Full,     DO10_Bay5_Pallet_Full],
                 [DO11_Bay1_Force_Discharge, DO12_Bay2_Force_Discharge, DO13_Bay3_Force_Discharge, DO14_Bay4_Force_Discharge, DO11_Bay1_Force_Discharge]];
            
            FOR i FROM 1 TO 2 DO
                FOR j FROM 1 TO 5 DO
                    IF mxDischarge_Signal{i,j} = 1 THEN
                        
                        IF i=1 THEN
                            TPWrite "Force Discharge Signal from PLC for Bay "\Num:=j;
                            IF mxStatus{2,j}=1 THEN !Check if there is empty pallet
                                Set mxPLC_Dicharge{2,j};
                                WaitTime 1;
                            ELSE
                                Set mxPLC_Dicharge{1,j};
                                mxDischarge_Signal{2,j}:= 1;
                                WaitDI arPallet_Present{j}, 0;
                            ENDIF                   
                            Reset mxPLC_Dicharge{1,j}; !Pallet Full
                            Reset mxPLC_Dicharge{2,j}; !Force Discharge
                            mxDischarge_Signal{2,j}:= 0; !Bay_Pallet_Full
                        
                        ELSEIF i=2 THEN
                            TPWrite "Pallet Full Signal from PLC for Bay "\Num:=j;
                            Set mxPLC_Dicharge{1,j};
                            WaitDI arPallet_Present{j}, 0;
                            Reset mxPLC_Dicharge{1,j}; !Pallet Full
                            mxDischarge_Signal{2,j}:= 0; !Bay_Pallet_Full
                        ENDIF
                        
                        !*** Empty Pallet Detected, Pick Pallet
                        IF arPallet_Present{j}=0 THEN
                            IF DI28_Pallet_Available=1 THEN
                                TPWrite "Empty Pallet Request Signal for Bay" \Num:=j;
                                
                                nBox_Layer:=0;
                                nBox_Count:=0;
                                mxStatus{3,j}:=0; !nBox_Layer
                                
                                !*** Pallet Pick Start
                                nSeqCode:=1;
                                wPalletPick:=wobj0;
                                pPalletPick:=pPalletPick_Conveyor;
                                Pallet_Pick;
            
                                !*** Pallet Place Start
                                arSeqCode_Place:= [3,5,7,17,21]; 
                                nSeqCode:=arSeqCode_Place{j}; !Array Selection for SeqCode
                                wPalletPlace:=wobj0;
                                arPallet_Place:= [pPalletPlace_Bay1, pPalletPlace_Bay2, pPalletPlace_Bay3, pPalletPlace_Bay4, pPalletPlace_Bay5];
                                pPalletPlace:= arPallet_Place{j}; !Array Selection for Target Address
                                Pallet_Place;
            
                                !*** Pallet Place End
                                nSeqCode:=0;
                                mxStatus{2,j}:=1; !nBox_Count
                                
                            ELSE
                                TPWrite "No Pallet Available";
                                WaitDI DI28_Pallet_Available,1;
                            ENDIF
                        ENDIF
                        
                        
                    ENDIF
                ENDFOR
            ENDFOR
            
            TPWrite "Checking Top/Bottom Box Ready signal from PLC";
            nCase_to_Bay_Code1:=GDI01_Bay_Selection;
            WaitTime 1;
            nCase_to_Bay_Code2:=GDI01_Bay_Selection;
            arList_Pattern:=[nBox_Pattern_Bay1, nBox_Pattern_Bay2, nBox_Pattern_Bay3, nBox_Pattern_Bay4, nBox_Pattern_Bay5];

            IF nCase_to_Bay_Code1=nCase_to_Bay_Code2 THEN
                nCase_to_Bay_Code1:=GDI01_Bay_Selection;
                IF nCase_to_Bay_Code1=nCase_to_Bay_Code2 THEN
                    nGDI_Case_to_Bay_Code:=nCase_to_Bay_Code2;
                    
                    IF nGDI_Case_to_Bay_Code<7 AND nGDI_Case_to_Bay_Code>0 THEN
                        Bay_Selected:
                        IF nGDI_Case_to_Bay_Code=6 THEN
                            TPWrite "Case to Bay: 6 (Automatic)";
                            FOR i FROM 1 TO 5 DO
                                IF arList_Pattern{i} = GDI00_Product_SKU THEN
                                    nGDI_Case_to_Bay_Code:= i;
                                    GOTO Bay_Selected;
                                ENDIF
                            ENDFOR
                            
                            IF nBox_Count_Bay1=1 AND DI16_Bay1_Pallet_Pres=1 THEN
                                nGDI_Case_to_Bay_Code:= 1;
                                GOTO Bay_Selected;
                            ENDIF
                            IF nBox_Count_Bay3=1 AND DI17_Bay2_Pallet_Pres=1 THEN
                                nGDI_Case_to_Bay_Code:= 3;
                                GOTO Bay_Selected;
                            ENDIF
                            IF nBox_Count_Bay2=1 AND DI18_Bay3_Pallet_Pres=1 THEN
                                nGDI_Case_to_Bay_Code:= 2;
                                GOTO Bay_Selected;
                            ENDIF
                            IF nBox_Count_Bay4=1 AND DI19_Bay4_Pallet_Pres=1 THEN
                                nGDI_Case_to_Bay_Code:= 4;
                                GOTO Bay_Selected;
                            ENDIF
                            IF nBox_Count_Bay5=1 AND DI20_Bay5_Pallet_Pres=1 THEN
                                nGDI_Case_to_Bay_Code:= 5;
                                GOTO Bay_Selected;
                            ENDIF
                            
                            TPWrite "All Bay Pallets are occupied, no ready pallet for new pattern/product";
                            TPReadFK nResponse_Key,"Has the pending product in line removed?","YES","EXIT","","","";
                            IF nResponse_Key=1 THEN
                                TPErase;
                                TPShow TP_PROGRAM;
                                GOTO Repeat;
                            ENDIF
                            IF nResponse_Key=2 THEN
                                TPErase;
                                TPShow TP_PROGRAM;
                                stop;
                                !EXIT;
                            ENDIF         
                        ENDIF
                        TPWrite "Case to Bay: "\Num:=nGDI_Case_to_Bay_Code;
                    ENDIF

                    mxDischarge_Signal:=
                [[DI11_Bay1_Force_Disc, DI12_Bay2_Force_Disc, DI13_Bay3_Force_Disc, DI14_Bay4_Force_Disc, DI15_Bay5_Force_Disc ],  
                 [dioBay1_Pallet_Full,  dioBay2_Pallet_Full,  dioBay3_Pallet_Full,  dioBay4_Pallet_Full,  dioBay5_Pallet_Full  ]];

                    
                    !***BOX PRESENT FOR BAY1 
                    IF ((nGDI_Case_to_Bay_Code=1 AND (DI26_Pick_Top=1 OR DI27_Pick_Bottom=1))AND DI16_Bay1_Pallet_Pres=1 AND DI11_Bay1_Force_Disc=0 AND dioBay1_Pallet_Full=0) THEN
                        station_number :=nGDI_Case_to_Bay_Code;
                        Box_Destination_Check;
                    ENDIF
                    !***BOX PRESENT FOR BAY2         
                    IF ((nGDI_Case_to_Bay_Code=2 AND (DI26_Pick_Top=1 OR DI27_Pick_Bottom=1))AND DI17_Bay2_Pallet_Pres=1 AND DI12_Bay2_Force_Disc=0 AND dioBay2_Pallet_Full=0) THEN
                        station_number :=nGDI_Case_to_Bay_Code;
                        Box_Destination_Check;
                    ENDIF
                    !***BOX PRESENT FOR BAY3 
                    IF ((nGDI_Case_to_Bay_Code=3 AND (DI26_Pick_Top=1 OR DI27_Pick_Bottom=1))AND DI18_Bay3_Pallet_Pres=1 AND DI13_Bay3_Force_Disc=0 AND dioBay3_Pallet_Full=0) THEN
                        station_number :=nGDI_Case_to_Bay_Code;
                        Box_Destination_Check;
                    ENDIF
                    !***BOX PRESENT FOR BAY4         
                    IF ((nGDI_Case_to_Bay_Code=4 AND (DI26_Pick_Top=1 OR DI27_Pick_Bottom=1))AND DI19_Bay4_Pallet_Pres=1 AND DI14_Bay4_Force_Disc=0 AND dioBay4_Pallet_Full=0) THEN
                        station_number :=nGDI_Case_to_Bay_Code;
                        Box_Destination_Check;
                    ENDIF
                    !***BOX PRESENT FOR BAY5         
                    IF ((nGDI_Case_to_Bay_Code=5 AND (DI26_Pick_Top=1 OR DI27_Pick_Bottom=1))AND DI20_Bay5_Pallet_Pres=1 AND DI15_Bay5_Force_Disc=0 AND dioBay5_Pallet_Full=0) THEN
                        station_number :=nGDI_Case_to_Bay_Code;
                        Box_Destination_Check;
                    ENDIF
                ENDIF
            ENDIF
            
            
            
            arDischarge_Signal
            arList_Pattern:=[nBoxPattern_A1, nBoxPattern_A2, nBoxPattern_A3, nBoxPattern_A4, nBoxPattern_A5];
            
            
            !*** (2) Scanning for full discharge signal
            
            !*** (3) Pick pallet for empty bay(s)
            
            !*** (4) Pick box for empty bay(s) with pallet
            
            
            
            
            
            
        ENDIF
    
        
    ENDPROC
    
    PROC Cycle_Setup()
        Reset DO01_Bay1_Pattern_Req;
        Reset DO02_Bay2_Pattern_Req;
        Reset DO03_Bay3_Pattern_Req;
        Reset DO04_Bay4_Pattern_Req;
        Reset DO05_Bay5_Pattern_Req;

        nErrorCode:=0;
        nSeqCode:=0;
        nResponse_Key:=0;
    ENDPROC
    
    PROC Initial_Arm_Move_Up()
!        Accset 80,100;
!        WaitTime 1;
!        pPerPos:=CRobT(\Tool:=GripNoLoad\WObj:=wobj0);
!        pCurPosit:=CPos(\Tool:=GripNoLoad\WObj:=wobj0);


!        pTooffset:=1900-pCurPosit.z;
!        pTooffsetx:=1080-pCurPosit.x;
!        !*******MOVEUP;    	
!        MoveL Offs(pPerPos,0,0,pTooffset),v500,z20,GripNoLoad;
!        MoveJ Offs(pOrigin,0,0,0),v2000,z50,GripNoLoad\WObj:=wobj0;
    ENDPROC
    
    PROC Tool_Home_Check()

        Return ;

!    ERROR
!        !	SETGO goErrorCode, nErrorCode;
!        IF ERRNO=ERR_WAIT_MAXTIME THEN
!            TEST nErrorCode
!            Case 1:
!                TPWrite "Pallet Gripper Close RS Alarm!";
!            Case 4:
!                TPWrite "Top Vacuum Home RS Alarm!";
!            Case 6:
!                TPWrite "Bottom Vacuum Home RS Alarm!";
!            Case 8:
!                TPWrite "Fork Home RS Alarm!";
!            Case 10:
!                TPWrite "Top Press Home RS Alarm!";
!            Case 14:
!                TPWrite "Box Vacuum ON/OFF Alarm!";
!            Case 15:
!                TPWrite "Pallet Sensing Home RS Alarm!";
!            ENDTEST
!            TPReadFK nResponse_Key,"Ready To Try Again ?","YES","EXIT","","","";
!            IF nResponse_Key=1 THEN
!                TPErase;
!                TPShow TP_PROGRAM;
!                !			SETGO goErrorCode, 0;
!                TEST nErrorCode
!                Case 1:
!                    RESET Y01_PGripperClose;
!                    !PULSEDO \Plength:=1, DO_PGripperOpen;
!                    WaitTime 1;
!                    SET Y01_PGripperClose;
!                    RETRY;
!                Case 4:
!                    RESET Y09_BTVacuumHome;
!                    WaitTime 1;
!                    SET Y09_BTVacuumHome;
!                    RETRY;
!                Case 6:
!                    RESET Y11_BBVacuumHome;
!                    WaitTime 1;
!                    SET Y11_BBVacuumHome;
!                    RETRY;
!                Case 8:
!                    RESET Y05_BForkHome;
!                    WaitTime 1;
!                    SET Y05_BForkHome;
!                    RETRY;
!                Case 10:
!                    RESET Y24_IAI_Start_Cmd;
!                    Set Y25_IAI_Reset_Cmd;
!                    RESET Y16_IAI_Pos1_Cmd;
!                    RESET Y17_IAI_Pos2_Cmd;
!                    RESET Y18_IAI_Pos4_Cmd;
!                    RESET Y19_IAI_Pos8_Cmd;
!                    WaitTime 0.5;
!                    Reset Y25_IAI_Reset_Cmd;
!                    SET Y20_IAI_Pos16_Cmd;
!                    WaitTime 0.5;
!                    SET Y24_IAI_Start_Cmd;
!                    RETRY;
!                Case 14:
!                    RESET Y12_BTVacuum_On;
!                    RESET Y13_BBVacuum_On;
!                    WaitTime 1;
!                    RETRY;
!                Case 15:
!                ENDTEST
!            ENDIF
!            IF nResponse_Key=2 THEN
!                Reset DO19_Robot_Hand_Abnormal;
!                TPErase;
!                TPShow TP_PROGRAM;
!                stop;
!                !EXIT;
!            ENDIF
!        ENDIF

    ENDPROC
    
    PROC Check_Pressure()
        
        IF DI_Robot_Gripper_Open=0 AND DI_Robot_Gripper_Close=0 
        THEN  
            !SetDO DO_PLC_Signal_Alarm,1;
            Alarm_Code:=14;                                      ! Alarm code #14 Check Air pressure
            TPErase;
    	    TPWrite "!!! Alarm code #14:";
            TPWrite "Check Air pressure";
            TPReadFK CurrentHt1, " ", stEmpty, stEmpty, stEmpty, stEmpty, "Acknowledge";
            SetDO DO_PLC_Signal_Alarm,0;
            Stop;
        ELSE
            RETURN;
        ENDIF
        
    ENDPROC
    
ENDMODULE