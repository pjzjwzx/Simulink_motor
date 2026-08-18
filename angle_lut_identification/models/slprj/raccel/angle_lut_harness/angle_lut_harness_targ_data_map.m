    function targMap = targDataMap(),

    ;%***********************
    ;% Create Parameter Map *
    ;%***********************
    
        nTotData      = 0; %add to this count as we go
        nTotSects     = 5;
        sectIdxOffset = 0;

        ;%
        ;% Define dummy sections & preallocate arrays
        ;%
        dumSection.nData = -1;
        dumSection.data  = [];

        dumData.logicalSrcIdx = -1;
        dumData.dtTransOffset = -1;

        ;%
        ;% Init/prealloc paramMap
        ;%
        paramMap.nSections           = nTotSects;
        paramMap.sectIdxOffset       = sectIdxOffset;
            paramMap.sections(nTotSects) = dumSection; %prealloc
        paramMap.nTotData            = -1;

        ;%
        ;% Auto data (rtP)
        ;%
            section.nData     = 31;
            section.data(31)  = dumData; %prealloc

                    ;% rtP.B
                    section.data(1).logicalSrcIdx = 0;
                    section.data(1).dtTransOffset = 0;

                    ;% rtP.BW_I
                    section.data(2).logicalSrcIdx = 1;
                    section.data(2).dtTransOffset = 1;

                    ;% rtP.BW_speed
                    section.data(3).logicalSrcIdx = 2;
                    section.data(3).dtTransOffset = 2;

                    ;% rtP.J
                    section.data(4).logicalSrcIdx = 3;
                    section.data(4).dtTransOffset = 3;

                    ;% rtP.Ld
                    section.data(5).logicalSrcIdx = 4;
                    section.data(5).dtTransOffset = 4;

                    ;% rtP.Lq
                    section.data(6).logicalSrcIdx = 5;
                    section.data(6).dtTransOffset = 5;

                    ;% rtP.Rs
                    section.data(7).logicalSrcIdx = 6;
                    section.data(7).dtTransOffset = 6;

                    ;% rtP.T_ident
                    section.data(8).logicalSrcIdx = 7;
                    section.data(8).dtTransOffset = 7;

                    ;% rtP.Vdc
                    section.data(9).logicalSrcIdx = 8;
                    section.data(9).dtTransOffset = 8;

                    ;% rtP.adc_current_gain
                    section.data(10).logicalSrcIdx = 9;
                    section.data(10).dtTransOffset = 9;

                    ;% rtP.adc_current_lsb_A
                    section.data(11).logicalSrcIdx = 10;
                    section.data(11).dtTransOffset = 10;

                    ;% rtP.adc_current_offset_a_A
                    section.data(12).logicalSrcIdx = 11;
                    section.data(12).dtTransOffset = 11;

                    ;% rtP.adc_current_offset_b_A
                    section.data(13).logicalSrcIdx = 12;
                    section.data(13).dtTransOffset = 12;

                    ;% rtP.adc_current_offset_c_A
                    section.data(14).logicalSrcIdx = 13;
                    section.data(14).dtTransOffset = 13;

                    ;% rtP.adc_current_range_A
                    section.data(15).logicalSrcIdx = 14;
                    section.data(15).dtTransOffset = 14;

                    ;% rtP.encoder_counts_per_rev
                    section.data(16).logicalSrcIdx = 15;
                    section.data(16).dtTransOffset = 15;

                    ;% rtP.encoder_error_bias_m_rad
                    section.data(17).logicalSrcIdx = 16;
                    section.data(17).dtTransOffset = 16;

                    ;% rtP.encoder_speed_lsb_radps
                    section.data(18).logicalSrcIdx = 17;
                    section.data(18).dtTransOffset = 17;

                    ;% rtP.encoder_speed_offset_radps
                    section.data(19).logicalSrcIdx = 18;
                    section.data(19).dtTransOffset = 18;

                    ;% rtP.encoder_theta_offset_rad
                    section.data(20).logicalSrcIdx = 19;
                    section.data(20).dtTransOffset = 19;

                    ;% rtP.inverter_voltage_drop_V
                    section.data(21).logicalSrcIdx = 20;
                    section.data(21).dtTransOffset = 20;

                    ;% rtP.pn
                    section.data(22).logicalSrcIdx = 21;
                    section.data(22).dtTransOffset = 21;

                    ;% rtP.psif
                    section.data(23).logicalSrcIdx = 22;
                    section.data(23).dtTransOffset = 22;

                    ;% rtP.pwm_deadtime_s
                    section.data(24).logicalSrcIdx = 23;
                    section.data(24).dtTransOffset = 23;

                    ;% rtP.pwm_max_duty
                    section.data(25).logicalSrcIdx = 24;
                    section.data(25).dtTransOffset = 24;

                    ;% rtP.pwm_min_duty
                    section.data(26).logicalSrcIdx = 25;
                    section.data(26).dtTransOffset = 25;

                    ;% rtP.pwm_min_pulse_duty
                    section.data(27).logicalSrcIdx = 26;
                    section.data(27).dtTransOffset = 26;

                    ;% rtP.stage1_load_torque_Nm
                    section.data(28).logicalSrcIdx = 27;
                    section.data(28).dtTransOffset = 27;

                    ;% rtP.stage1_overmod_epsilon
                    section.data(29).logicalSrcIdx = 28;
                    section.data(29).dtTransOffset = 28;

                    ;% rtP.stage1_speed_target_rpm
                    section.data(30).logicalSrcIdx = 29;
                    section.data(30).dtTransOffset = 29;

                    ;% rtP.theta0_e_rad
                    section.data(31).logicalSrcIdx = 30;
                    section.data(31).dtTransOffset = 30;

            nTotData = nTotData + section.nData;
            paramMap.sections(1) = section;
            clear section

            section.nData     = 2;
            section.data(2)  = dumData; %prealloc

                    ;% rtP.encoder_noise_seed
                    section.data(1).logicalSrcIdx = 31;
                    section.data(1).dtTransOffset = 0;

                    ;% rtP.stage1_current_noise_seed
                    section.data(2).logicalSrcIdx = 32;
                    section.data(2).dtTransOffset = 1;

            nTotData = nTotData + section.nData;
            paramMap.sections(2) = section;
            clear section

            section.nData     = 2;
            section.data(2)  = dumData; %prealloc

                    ;% rtP.encoder_error_mode
                    section.data(1).logicalSrcIdx = 33;
                    section.data(1).dtTransOffset = 0;

                    ;% rtP.sensor_mode
                    section.data(2).logicalSrcIdx = 34;
                    section.data(2).dtTransOffset = 1;

            nTotData = nTotData + section.nData;
            paramMap.sections(3) = section;
            clear section

            section.nData     = 108;
            section.data(108)  = dumData; %prealloc

                    ;% rtP.PIDController1_InitialConditionForIntegrator
                    section.data(1).logicalSrcIdx = 35;
                    section.data(1).dtTransOffset = 0;

                    ;% rtP.PIDController2_InitialConditionForIntegrator
                    section.data(2).logicalSrcIdx = 36;
                    section.data(2).dtTransOffset = 1;

                    ;% rtP.PIDController_InitialConditionForIntegrator
                    section.data(3).logicalSrcIdx = 37;
                    section.data(3).dtTransOffset = 2;

                    ;% rtP.PIDController_LowerIntegratorSaturationLimit
                    section.data(4).logicalSrcIdx = 38;
                    section.data(4).dtTransOffset = 3;

                    ;% rtP.PIDController2_LowerSaturationLimit
                    section.data(5).logicalSrcIdx = 39;
                    section.data(5).dtTransOffset = 4;

                    ;% rtP.PIDController_UpperIntegratorSaturationLimit
                    section.data(6).logicalSrcIdx = 40;
                    section.data(6).dtTransOffset = 5;

                    ;% rtP.PIDController2_UpperSaturationLimit
                    section.data(7).logicalSrcIdx = 41;
                    section.data(7).dtTransOffset = 6;

                    ;% rtP.DiscreteRateLimiter2_Vinit
                    section.data(8).logicalSrcIdx = 42;
                    section.data(8).dtTransOffset = 7;

                    ;% rtP.DiscreteRateLimiter_Vinit
                    section.data(9).logicalSrcIdx = 43;
                    section.data(9).dtTransOffset = 8;

                    ;% rtP.SurfaceMountPMSM_idq0
                    section.data(10).logicalSrcIdx = 44;
                    section.data(10).dtTransOffset = 9;

                    ;% rtP.SurfaceMountPMSM_mechanical
                    section.data(11).logicalSrcIdx = 45;
                    section.data(11).dtTransOffset = 11;

                    ;% rtP.SurfaceMountPMSM_omega_init
                    section.data(12).logicalSrcIdx = 46;
                    section.data(12).dtTransOffset = 14;

                    ;% rtP.RepeatingSequence_rep_seq_y
                    section.data(13).logicalSrcIdx = 47;
                    section.data(13).dtTransOffset = 15;

                    ;% rtP.SurfaceMountPMSM_theta_init
                    section.data(14).logicalSrcIdx = 48;
                    section.data(14).dtTransOffset = 18;

                    ;% rtP.DataStoreMemory_InitialValue
                    section.data(15).logicalSrcIdx = 49;
                    section.data(15).dtTransOffset = 19;

                    ;% rtP.DiscreteTimeIntegrator_gainval
                    section.data(16).logicalSrcIdx = 50;
                    section.data(16).dtTransOffset = 20;

                    ;% rtP.DiscreteTimeIntegrator_IC
                    section.data(17).logicalSrcIdx = 51;
                    section.data(17).dtTransOffset = 21;

                    ;% rtP.Constant_Value
                    section.data(18).logicalSrcIdx = 52;
                    section.data(18).dtTransOffset = 22;

                    ;% rtP.Current_Sensing_ADC_Latency_Ia_InitialCondition
                    section.data(19).logicalSrcIdx = 53;
                    section.data(19).dtTransOffset = 23;

                    ;% rtP.Current_Sensing_ADC_Latency_Ib_InitialCondition
                    section.data(20).logicalSrcIdx = 54;
                    section.data(20).dtTransOffset = 24;

                    ;% rtP.Current_Sensing_ADC_Latency_Ic_InitialCondition
                    section.data(21).logicalSrcIdx = 55;
                    section.data(21).dtTransOffset = 25;

                    ;% rtP.Position_Sensing_Encoder_Latency_Theta_InitialCondition
                    section.data(22).logicalSrcIdx = 56;
                    section.data(22).dtTransOffset = 26;

                    ;% rtP.Integrator_gainval
                    section.data(23).logicalSrcIdx = 57;
                    section.data(23).dtTransOffset = 27;

                    ;% rtP.Int_UpperSat
                    section.data(24).logicalSrcIdx = 58;
                    section.data(24).dtTransOffset = 28;

                    ;% rtP.Int_LowerSat
                    section.data(25).logicalSrcIdx = 59;
                    section.data(25).dtTransOffset = 29;

                    ;% rtP.SpeedSetpointRPM2_Time
                    section.data(26).logicalSrcIdx = 60;
                    section.data(26).dtTransOffset = 30;

                    ;% rtP.SpeedSetpointRPM2_Y0
                    section.data(27).logicalSrcIdx = 61;
                    section.data(27).dtTransOffset = 31;

                    ;% rtP.Saturation_UpperSat
                    section.data(28).logicalSrcIdx = 62;
                    section.data(28).dtTransOffset = 32;

                    ;% rtP.Saturation_LowerSat
                    section.data(29).logicalSrcIdx = 63;
                    section.data(29).dtTransOffset = 33;

                    ;% rtP.u_Gain
                    section.data(30).logicalSrcIdx = 64;
                    section.data(30).dtTransOffset = 34;

                    ;% rtP.Position_Sensing_Encoder_Latency_Wm_InitialCondition
                    section.data(31).logicalSrcIdx = 65;
                    section.data(31).dtTransOffset = 35;

                    ;% rtP.Integrator_gainval_jrco2bwd10
                    section.data(32).logicalSrcIdx = 66;
                    section.data(32).dtTransOffset = 36;

                    ;% rtP.Integrator_UpperSat
                    section.data(33).logicalSrcIdx = 67;
                    section.data(33).dtTransOffset = 37;

                    ;% rtP.Integrator_LowerSat
                    section.data(34).logicalSrcIdx = 68;
                    section.data(34).dtTransOffset = 38;

                    ;% rtP.Integrator_UpperSat_fnb5xkuneo
                    section.data(35).logicalSrcIdx = 69;
                    section.data(35).dtTransOffset = 39;

                    ;% rtP.Integrator_LowerSat_nku0pa42gn
                    section.data(36).logicalSrcIdx = 70;
                    section.data(36).dtTransOffset = 40;

                    ;% rtP.Integrator_gainval_fm3inckqoz
                    section.data(37).logicalSrcIdx = 71;
                    section.data(37).dtTransOffset = 41;

                    ;% rtP.UnitDelay3_InitialCondition
                    section.data(38).logicalSrcIdx = 72;
                    section.data(38).dtTransOffset = 42;

                    ;% rtP.UnitDelay1_InitialCondition
                    section.data(39).logicalSrcIdx = 73;
                    section.data(39).dtTransOffset = 43;

                    ;% rtP.UnitDelay2_InitialCondition
                    section.data(40).logicalSrcIdx = 74;
                    section.data(40).dtTransOffset = 44;

                    ;% rtP.Saturation2_UpperSat
                    section.data(41).logicalSrcIdx = 75;
                    section.data(41).dtTransOffset = 45;

                    ;% rtP.Saturation2_LowerSat
                    section.data(42).logicalSrcIdx = 76;
                    section.data(42).dtTransOffset = 46;

                    ;% rtP.Gain_Gain
                    section.data(43).logicalSrcIdx = 77;
                    section.data(43).dtTransOffset = 47;

                    ;% rtP.Gain2_Gain
                    section.data(44).logicalSrcIdx = 78;
                    section.data(44).dtTransOffset = 48;

                    ;% rtP.Gain3_Gain
                    section.data(45).logicalSrcIdx = 79;
                    section.data(45).dtTransOffset = 49;

                    ;% rtP.Gain1_Gain
                    section.data(46).logicalSrcIdx = 80;
                    section.data(46).dtTransOffset = 50;

                    ;% rtP.Gain4_Gain
                    section.data(47).logicalSrcIdx = 81;
                    section.data(47).dtTransOffset = 51;

                    ;% rtP.SpeedSetpointRPM_Time
                    section.data(48).logicalSrcIdx = 82;
                    section.data(48).dtTransOffset = 52;

                    ;% rtP.SpeedSetpointRPM_Y0
                    section.data(49).logicalSrcIdx = 83;
                    section.data(49).dtTransOffset = 53;

                    ;% rtP.Saturation_UpperSat_ngwwjyhsfd
                    section.data(50).logicalSrcIdx = 84;
                    section.data(50).dtTransOffset = 54;

                    ;% rtP.Saturation_LowerSat_f5gxnsbbt2
                    section.data(51).logicalSrcIdx = 85;
                    section.data(51).dtTransOffset = 55;

                    ;% rtP.Inverter_Nonideal_Gain
                    section.data(52).logicalSrcIdx = 86;
                    section.data(52).dtTransOffset = 56;

                    ;% rtP.Gain_Gain_bfdvzkemvr
                    section.data(53).logicalSrcIdx = 87;
                    section.data(53).dtTransOffset = 57;

                    ;% rtP.Gain1_Gain_f4yqqgp53n
                    section.data(54).logicalSrcIdx = 88;
                    section.data(54).dtTransOffset = 58;

                    ;% rtP.Gain4_Gain_cbzrmf0dwt
                    section.data(55).logicalSrcIdx = 89;
                    section.data(55).dtTransOffset = 59;

                    ;% rtP.Gain2_Gain_apsi0kf2uv
                    section.data(56).logicalSrcIdx = 90;
                    section.data(56).dtTransOffset = 60;

                    ;% rtP.Gain3_Gain_aqc1lmstlp
                    section.data(57).logicalSrcIdx = 91;
                    section.data(57).dtTransOffset = 61;

                    ;% rtP.Gain1_Gain_kezbkczt35
                    section.data(58).logicalSrcIdx = 92;
                    section.data(58).dtTransOffset = 62;

                    ;% rtP.current_noise_a_Mean
                    section.data(59).logicalSrcIdx = 93;
                    section.data(59).dtTransOffset = 63;

                    ;% rtP.current_noise_a_StdDev
                    section.data(60).logicalSrcIdx = 94;
                    section.data(60).dtTransOffset = 64;

                    ;% rtP.current_noise_b_Mean
                    section.data(61).logicalSrcIdx = 95;
                    section.data(61).dtTransOffset = 65;

                    ;% rtP.current_noise_b_StdDev
                    section.data(62).logicalSrcIdx = 96;
                    section.data(62).dtTransOffset = 66;

                    ;% rtP.current_noise_c_Mean
                    section.data(63).logicalSrcIdx = 97;
                    section.data(63).dtTransOffset = 67;

                    ;% rtP.current_noise_c_StdDev
                    section.data(64).logicalSrcIdx = 98;
                    section.data(64).dtTransOffset = 68;

                    ;% rtP.Encoder_Angle_Noise_Mean
                    section.data(65).logicalSrcIdx = 99;
                    section.data(65).dtTransOffset = 69;

                    ;% rtP.Encoder_Angle_Noise_StdDev
                    section.data(66).logicalSrcIdx = 100;
                    section.data(66).dtTransOffset = 70;

                    ;% rtP.Control_Compute_Delay_Vd_InitialCondition
                    section.data(67).logicalSrcIdx = 101;
                    section.data(67).dtTransOffset = 71;

                    ;% rtP.Control_Compute_Delay_Vq_InitialCondition
                    section.data(68).logicalSrcIdx = 102;
                    section.data(68).dtTransOffset = 72;

                    ;% rtP.Gain2_Gain_bfibyfcm43
                    section.data(69).logicalSrcIdx = 103;
                    section.data(69).dtTransOffset = 73;

                    ;% rtP.LookUpTable1_bp01Data
                    section.data(70).logicalSrcIdx = 104;
                    section.data(70).dtTransOffset = 74;

                    ;% rtP.Gain5_Gain
                    section.data(71).logicalSrcIdx = 105;
                    section.data(71).dtTransOffset = 77;

                    ;% rtP.UnitDelay6_InitialCondition
                    section.data(72).logicalSrcIdx = 106;
                    section.data(72).dtTransOffset = 78;

                    ;% rtP.UnitDelay4_InitialCondition
                    section.data(73).logicalSrcIdx = 107;
                    section.data(73).dtTransOffset = 79;

                    ;% rtP.Constant_Value_epnbynriee
                    section.data(74).logicalSrcIdx = 108;
                    section.data(74).dtTransOffset = 80;

                    ;% rtP.Switch_Threshold
                    section.data(75).logicalSrcIdx = 109;
                    section.data(75).dtTransOffset = 81;

                    ;% rtP.Constant_Value_hqnvu24bt3
                    section.data(76).logicalSrcIdx = 110;
                    section.data(76).dtTransOffset = 82;

                    ;% rtP.Constant1_Value
                    section.data(77).logicalSrcIdx = 111;
                    section.data(77).dtTransOffset = 83;

                    ;% rtP.Constant11_Value
                    section.data(78).logicalSrcIdx = 112;
                    section.data(78).dtTransOffset = 84;

                    ;% rtP.Constant12_Value
                    section.data(79).logicalSrcIdx = 113;
                    section.data(79).dtTransOffset = 85;

                    ;% rtP.Constant6_Value
                    section.data(80).logicalSrcIdx = 114;
                    section.data(80).dtTransOffset = 86;

                    ;% rtP.Mechanical_Wrap_Modulus_Value
                    section.data(81).logicalSrcIdx = 115;
                    section.data(81).dtTransOffset = 87;

                    ;% rtP.Zero_Error_Value
                    section.data(82).logicalSrcIdx = 116;
                    section.data(82).dtTransOffset = 88;

                    ;% rtP.Constant_Value_nfrdqc41td
                    section.data(83).logicalSrcIdx = 117;
                    section.data(83).dtTransOffset = 89;

                    ;% rtP.Constant1_Value_kb5t55ka4c
                    section.data(84).logicalSrcIdx = 118;
                    section.data(84).dtTransOffset = 90;

                    ;% rtP.Constant3_Value
                    section.data(85).logicalSrcIdx = 119;
                    section.data(85).dtTransOffset = 91;

                    ;% rtP.Constant5_Value
                    section.data(86).logicalSrcIdx = 120;
                    section.data(86).dtTransOffset = 92;

                    ;% rtP.Constant1_Value_gwaqkxkpzi
                    section.data(87).logicalSrcIdx = 121;
                    section.data(87).dtTransOffset = 93;

                    ;% rtP.Constant_Value_nkd0bfvul3
                    section.data(88).logicalSrcIdx = 122;
                    section.data(88).dtTransOffset = 94;

                    ;% rtP.Constant2_Value
                    section.data(89).logicalSrcIdx = 123;
                    section.data(89).dtTransOffset = 96;

                    ;% rtP.Constant1_Value_fal53opp3n
                    section.data(90).logicalSrcIdx = 124;
                    section.data(90).dtTransOffset = 97;

                    ;% rtP.Constant_Value_hxwns5f3a4
                    section.data(91).logicalSrcIdx = 125;
                    section.data(91).dtTransOffset = 98;

                    ;% rtP.Constant1_Value_dsldruknvq
                    section.data(92).logicalSrcIdx = 126;
                    section.data(92).dtTransOffset = 100;

                    ;% rtP.Constant_Value_ltzat0eviz
                    section.data(93).logicalSrcIdx = 127;
                    section.data(93).dtTransOffset = 101;

                    ;% rtP.Constant1_Value_cnxhsvnkpf
                    section.data(94).logicalSrcIdx = 128;
                    section.data(94).dtTransOffset = 103;

                    ;% rtP.Constant2_Value_ixdnz3zgzg
                    section.data(95).logicalSrcIdx = 129;
                    section.data(95).dtTransOffset = 104;

                    ;% rtP.Constant1_Value_ime35ehw4h
                    section.data(96).logicalSrcIdx = 130;
                    section.data(96).dtTransOffset = 105;

                    ;% rtP.Constant2_Value_dp504jpcdx
                    section.data(97).logicalSrcIdx = 131;
                    section.data(97).dtTransOffset = 107;

                    ;% rtP.Constant1_Value_kqqdla0atg
                    section.data(98).logicalSrcIdx = 132;
                    section.data(98).dtTransOffset = 108;

                    ;% rtP.Constant_Value_ddd44ptvyk
                    section.data(99).logicalSrcIdx = 133;
                    section.data(99).dtTransOffset = 109;

                    ;% rtP.Constant1_Value_ootv1z4abu
                    section.data(100).logicalSrcIdx = 134;
                    section.data(100).dtTransOffset = 111;

                    ;% rtP.Constant_Value_k2kkxajxsy
                    section.data(101).logicalSrcIdx = 135;
                    section.data(101).dtTransOffset = 112;

                    ;% rtP.Constant1_Value_iplzjv30is
                    section.data(102).logicalSrcIdx = 136;
                    section.data(102).dtTransOffset = 114;

                    ;% rtP.Constant2_Value_j21pxnnccw
                    section.data(103).logicalSrcIdx = 137;
                    section.data(103).dtTransOffset = 115;

                    ;% rtP.Constant_Value_au2sfpopuq
                    section.data(104).logicalSrcIdx = 138;
                    section.data(104).dtTransOffset = 116;

                    ;% rtP.Constant1_Value_cdkymhk2bj
                    section.data(105).logicalSrcIdx = 139;
                    section.data(105).dtTransOffset = 117;

                    ;% rtP.Constant2_Value_afxbs1y1pp
                    section.data(106).logicalSrcIdx = 140;
                    section.data(106).dtTransOffset = 119;

                    ;% rtP.Constant1_Value_njijylfm1i
                    section.data(107).logicalSrcIdx = 141;
                    section.data(107).dtTransOffset = 120;

                    ;% rtP.Constant2_Value_dd1sscqjpw
                    section.data(108).logicalSrcIdx = 142;
                    section.data(108).dtTransOffset = 122;

            nTotData = nTotData + section.nData;
            paramMap.sections(4) = section;
            clear section

            section.nData     = 5;
            section.data(5)  = dumData; %prealloc

                    ;% rtP.Select_Error_Mode_Threshold
                    section.data(1).logicalSrcIdx = 143;
                    section.data(1).dtTransOffset = 0;

                    ;% rtP.Select_Sensor_Mode_Mechanical_Threshold
                    section.data(2).logicalSrcIdx = 144;
                    section.data(2).dtTransOffset = 1;

                    ;% rtP.Select_Sensor_Mode_Error_Threshold
                    section.data(3).logicalSrcIdx = 145;
                    section.data(3).dtTransOffset = 2;

                    ;% rtP.Select_Sensor_Mode_Electrical_Threshold
                    section.data(4).logicalSrcIdx = 146;
                    section.data(4).dtTransOffset = 3;

                    ;% rtP.Select_Off_Or_Fixed_Threshold
                    section.data(5).logicalSrcIdx = 147;
                    section.data(5).dtTransOffset = 4;

            nTotData = nTotData + section.nData;
            paramMap.sections(5) = section;
            clear section


            ;%
            ;% Non-auto Data (parameter)
            ;%


        ;%
        ;% Add final counts to struct.
        ;%
        paramMap.nTotData = nTotData;



    ;%**************************
    ;% Create Block Output Map *
    ;%**************************
    
        nTotData      = 0; %add to this count as we go
        nTotSects     = 2;
        sectIdxOffset = 0;

        ;%
        ;% Define dummy sections & preallocate arrays
        ;%
        dumSection.nData = -1;
        dumSection.data  = [];

        dumData.logicalSrcIdx = -1;
        dumData.dtTransOffset = -1;

        ;%
        ;% Init/prealloc sigMap
        ;%
        sigMap.nSections           = nTotSects;
        sigMap.sectIdxOffset       = sectIdxOffset;
            sigMap.sections(nTotSects) = dumSection; %prealloc
        sigMap.nTotData            = -1;

        ;%
        ;% Auto data (rtB)
        ;%
            section.nData     = 118;
            section.data(118)  = dumData; %prealloc

                    ;% rtB.pmwrvmuv2z
                    section.data(1).logicalSrcIdx = 0;
                    section.data(1).dtTransOffset = 0;

                    ;% rtB.abtahjutxs
                    section.data(2).logicalSrcIdx = 1;
                    section.data(2).dtTransOffset = 1;

                    ;% rtB.djegpsthsy
                    section.data(3).logicalSrcIdx = 2;
                    section.data(3).dtTransOffset = 2;

                    ;% rtB.k1gznu2cip
                    section.data(4).logicalSrcIdx = 3;
                    section.data(4).dtTransOffset = 3;

                    ;% rtB.a0zjwtlk4t
                    section.data(5).logicalSrcIdx = 4;
                    section.data(5).dtTransOffset = 4;

                    ;% rtB.hmznkt13gh
                    section.data(6).logicalSrcIdx = 5;
                    section.data(6).dtTransOffset = 5;

                    ;% rtB.pkclptk1iu
                    section.data(7).logicalSrcIdx = 6;
                    section.data(7).dtTransOffset = 6;

                    ;% rtB.bva1copsfh
                    section.data(8).logicalSrcIdx = 7;
                    section.data(8).dtTransOffset = 7;

                    ;% rtB.kmrdohh114
                    section.data(9).logicalSrcIdx = 8;
                    section.data(9).dtTransOffset = 8;

                    ;% rtB.lnib30af4p
                    section.data(10).logicalSrcIdx = 9;
                    section.data(10).dtTransOffset = 9;

                    ;% rtB.j0yc5f3kku
                    section.data(11).logicalSrcIdx = 10;
                    section.data(11).dtTransOffset = 10;

                    ;% rtB.b3jdreufcl
                    section.data(12).logicalSrcIdx = 11;
                    section.data(12).dtTransOffset = 11;

                    ;% rtB.ku4jk3u1b1
                    section.data(13).logicalSrcIdx = 12;
                    section.data(13).dtTransOffset = 12;

                    ;% rtB.p50nhc4qqf
                    section.data(14).logicalSrcIdx = 13;
                    section.data(14).dtTransOffset = 13;

                    ;% rtB.itaesr4vi5
                    section.data(15).logicalSrcIdx = 14;
                    section.data(15).dtTransOffset = 14;

                    ;% rtB.kohbaqjau1
                    section.data(16).logicalSrcIdx = 15;
                    section.data(16).dtTransOffset = 15;

                    ;% rtB.ipp4rrhurt
                    section.data(17).logicalSrcIdx = 16;
                    section.data(17).dtTransOffset = 16;

                    ;% rtB.iygzcfg52o
                    section.data(18).logicalSrcIdx = 17;
                    section.data(18).dtTransOffset = 17;

                    ;% rtB.njqjiipllc
                    section.data(19).logicalSrcIdx = 18;
                    section.data(19).dtTransOffset = 18;

                    ;% rtB.a2vdpdjjhp
                    section.data(20).logicalSrcIdx = 19;
                    section.data(20).dtTransOffset = 19;

                    ;% rtB.bmgyv20kuq
                    section.data(21).logicalSrcIdx = 20;
                    section.data(21).dtTransOffset = 20;

                    ;% rtB.mtlkklsgi2
                    section.data(22).logicalSrcIdx = 21;
                    section.data(22).dtTransOffset = 21;

                    ;% rtB.fgydxbqcob
                    section.data(23).logicalSrcIdx = 22;
                    section.data(23).dtTransOffset = 22;

                    ;% rtB.k3xqxyxmut
                    section.data(24).logicalSrcIdx = 23;
                    section.data(24).dtTransOffset = 23;

                    ;% rtB.kss5c3pzf2
                    section.data(25).logicalSrcIdx = 24;
                    section.data(25).dtTransOffset = 24;

                    ;% rtB.nw2r1p4typ
                    section.data(26).logicalSrcIdx = 25;
                    section.data(26).dtTransOffset = 25;

                    ;% rtB.bpzykzheeg
                    section.data(27).logicalSrcIdx = 26;
                    section.data(27).dtTransOffset = 28;

                    ;% rtB.lvdjxazx04
                    section.data(28).logicalSrcIdx = 27;
                    section.data(28).dtTransOffset = 31;

                    ;% rtB.pbjw4qgbfo
                    section.data(29).logicalSrcIdx = 28;
                    section.data(29).dtTransOffset = 32;

                    ;% rtB.avn1p5wdq4
                    section.data(30).logicalSrcIdx = 29;
                    section.data(30).dtTransOffset = 33;

                    ;% rtB.f1e2elmt3s
                    section.data(31).logicalSrcIdx = 30;
                    section.data(31).dtTransOffset = 34;

                    ;% rtB.dy45qiahhv
                    section.data(32).logicalSrcIdx = 31;
                    section.data(32).dtTransOffset = 35;

                    ;% rtB.njytyfycdb
                    section.data(33).logicalSrcIdx = 32;
                    section.data(33).dtTransOffset = 36;

                    ;% rtB.pg4y2334si
                    section.data(34).logicalSrcIdx = 33;
                    section.data(34).dtTransOffset = 37;

                    ;% rtB.cvfrgx4lmu
                    section.data(35).logicalSrcIdx = 34;
                    section.data(35).dtTransOffset = 40;

                    ;% rtB.o0zh4dpwof
                    section.data(36).logicalSrcIdx = 35;
                    section.data(36).dtTransOffset = 41;

                    ;% rtB.apfmkwq5cx
                    section.data(37).logicalSrcIdx = 36;
                    section.data(37).dtTransOffset = 42;

                    ;% rtB.nsr2koyppz
                    section.data(38).logicalSrcIdx = 37;
                    section.data(38).dtTransOffset = 43;

                    ;% rtB.ah2f3obaf2
                    section.data(39).logicalSrcIdx = 38;
                    section.data(39).dtTransOffset = 44;

                    ;% rtB.poc05a2t00
                    section.data(40).logicalSrcIdx = 39;
                    section.data(40).dtTransOffset = 45;

                    ;% rtB.kjpxk43vb5
                    section.data(41).logicalSrcIdx = 40;
                    section.data(41).dtTransOffset = 46;

                    ;% rtB.kj1et5qiw3
                    section.data(42).logicalSrcIdx = 41;
                    section.data(42).dtTransOffset = 47;

                    ;% rtB.dis1gyghp5
                    section.data(43).logicalSrcIdx = 42;
                    section.data(43).dtTransOffset = 48;

                    ;% rtB.iiu52do3gh
                    section.data(44).logicalSrcIdx = 43;
                    section.data(44).dtTransOffset = 49;

                    ;% rtB.ja2usbfqvp
                    section.data(45).logicalSrcIdx = 44;
                    section.data(45).dtTransOffset = 50;

                    ;% rtB.ocsbq5uu0u
                    section.data(46).logicalSrcIdx = 45;
                    section.data(46).dtTransOffset = 51;

                    ;% rtB.phjxq1gpwe
                    section.data(47).logicalSrcIdx = 46;
                    section.data(47).dtTransOffset = 52;

                    ;% rtB.bqzlafhwzj
                    section.data(48).logicalSrcIdx = 47;
                    section.data(48).dtTransOffset = 53;

                    ;% rtB.ohazbdfvqd
                    section.data(49).logicalSrcIdx = 48;
                    section.data(49).dtTransOffset = 54;

                    ;% rtB.eyl5olnvxu
                    section.data(50).logicalSrcIdx = 49;
                    section.data(50).dtTransOffset = 55;

                    ;% rtB.cvaq3eiog1
                    section.data(51).logicalSrcIdx = 50;
                    section.data(51).dtTransOffset = 56;

                    ;% rtB.ps50vu2w2e
                    section.data(52).logicalSrcIdx = 51;
                    section.data(52).dtTransOffset = 57;

                    ;% rtB.nccfrl32mm
                    section.data(53).logicalSrcIdx = 52;
                    section.data(53).dtTransOffset = 58;

                    ;% rtB.aq3z3j00nc
                    section.data(54).logicalSrcIdx = 53;
                    section.data(54).dtTransOffset = 61;

                    ;% rtB.i5s0x2u0ry
                    section.data(55).logicalSrcIdx = 54;
                    section.data(55).dtTransOffset = 62;

                    ;% rtB.ln5hdszlm0
                    section.data(56).logicalSrcIdx = 55;
                    section.data(56).dtTransOffset = 63;

                    ;% rtB.dygndsrxsu
                    section.data(57).logicalSrcIdx = 56;
                    section.data(57).dtTransOffset = 64;

                    ;% rtB.lopwn0zgm3
                    section.data(58).logicalSrcIdx = 57;
                    section.data(58).dtTransOffset = 65;

                    ;% rtB.ih4lvzhbj2
                    section.data(59).logicalSrcIdx = 58;
                    section.data(59).dtTransOffset = 66;

                    ;% rtB.fdad4czr4f
                    section.data(60).logicalSrcIdx = 59;
                    section.data(60).dtTransOffset = 67;

                    ;% rtB.eod0a04v3n
                    section.data(61).logicalSrcIdx = 60;
                    section.data(61).dtTransOffset = 68;

                    ;% rtB.aa2tdapnrf
                    section.data(62).logicalSrcIdx = 61;
                    section.data(62).dtTransOffset = 69;

                    ;% rtB.jg303qa15q
                    section.data(63).logicalSrcIdx = 62;
                    section.data(63).dtTransOffset = 70;

                    ;% rtB.ibhfc1kvps
                    section.data(64).logicalSrcIdx = 63;
                    section.data(64).dtTransOffset = 71;

                    ;% rtB.fxc14bmc3y
                    section.data(65).logicalSrcIdx = 64;
                    section.data(65).dtTransOffset = 72;

                    ;% rtB.jdef0f5arc
                    section.data(66).logicalSrcIdx = 65;
                    section.data(66).dtTransOffset = 73;

                    ;% rtB.mx2i5f5vhu
                    section.data(67).logicalSrcIdx = 66;
                    section.data(67).dtTransOffset = 74;

                    ;% rtB.box5mhqznz
                    section.data(68).logicalSrcIdx = 67;
                    section.data(68).dtTransOffset = 75;

                    ;% rtB.ke5b3yiry1
                    section.data(69).logicalSrcIdx = 68;
                    section.data(69).dtTransOffset = 76;

                    ;% rtB.jxxvyc5xpz
                    section.data(70).logicalSrcIdx = 69;
                    section.data(70).dtTransOffset = 77;

                    ;% rtB.al1ilorn2w
                    section.data(71).logicalSrcIdx = 70;
                    section.data(71).dtTransOffset = 78;

                    ;% rtB.bljwlt1rov
                    section.data(72).logicalSrcIdx = 71;
                    section.data(72).dtTransOffset = 79;

                    ;% rtB.cjrqr42n2b
                    section.data(73).logicalSrcIdx = 72;
                    section.data(73).dtTransOffset = 80;

                    ;% rtB.m0vdook5kv
                    section.data(74).logicalSrcIdx = 73;
                    section.data(74).dtTransOffset = 81;

                    ;% rtB.okzfq3hfot
                    section.data(75).logicalSrcIdx = 74;
                    section.data(75).dtTransOffset = 82;

                    ;% rtB.eglcazss1c
                    section.data(76).logicalSrcIdx = 75;
                    section.data(76).dtTransOffset = 83;

                    ;% rtB.nj04wgaqgx
                    section.data(77).logicalSrcIdx = 76;
                    section.data(77).dtTransOffset = 84;

                    ;% rtB.khhsrkvjcp
                    section.data(78).logicalSrcIdx = 77;
                    section.data(78).dtTransOffset = 85;

                    ;% rtB.dwlbdu3dqb
                    section.data(79).logicalSrcIdx = 78;
                    section.data(79).dtTransOffset = 86;

                    ;% rtB.o5p1bykpmb
                    section.data(80).logicalSrcIdx = 79;
                    section.data(80).dtTransOffset = 87;

                    ;% rtB.oat5lyyojj
                    section.data(81).logicalSrcIdx = 80;
                    section.data(81).dtTransOffset = 88;

                    ;% rtB.cluwvyj2v0
                    section.data(82).logicalSrcIdx = 81;
                    section.data(82).dtTransOffset = 89;

                    ;% rtB.inve0zctyf
                    section.data(83).logicalSrcIdx = 82;
                    section.data(83).dtTransOffset = 90;

                    ;% rtB.bflux0vfd3
                    section.data(84).logicalSrcIdx = 83;
                    section.data(84).dtTransOffset = 91;

                    ;% rtB.o0raraegud
                    section.data(85).logicalSrcIdx = 84;
                    section.data(85).dtTransOffset = 92;

                    ;% rtB.pojhuauetl
                    section.data(86).logicalSrcIdx = 85;
                    section.data(86).dtTransOffset = 93;

                    ;% rtB.d1qa04zhcn
                    section.data(87).logicalSrcIdx = 86;
                    section.data(87).dtTransOffset = 94;

                    ;% rtB.cuiqpgxqvu
                    section.data(88).logicalSrcIdx = 87;
                    section.data(88).dtTransOffset = 95;

                    ;% rtB.dax1enud2z
                    section.data(89).logicalSrcIdx = 88;
                    section.data(89).dtTransOffset = 96;

                    ;% rtB.lq0la1f51o
                    section.data(90).logicalSrcIdx = 89;
                    section.data(90).dtTransOffset = 97;

                    ;% rtB.ohpe41w4s1
                    section.data(91).logicalSrcIdx = 90;
                    section.data(91).dtTransOffset = 98;

                    ;% rtB.alxkk0ezfw
                    section.data(92).logicalSrcIdx = 91;
                    section.data(92).dtTransOffset = 99;

                    ;% rtB.gfb5kery4u
                    section.data(93).logicalSrcIdx = 92;
                    section.data(93).dtTransOffset = 100;

                    ;% rtB.fvk0nxl0zm
                    section.data(94).logicalSrcIdx = 93;
                    section.data(94).dtTransOffset = 101;

                    ;% rtB.ippnl13plf
                    section.data(95).logicalSrcIdx = 94;
                    section.data(95).dtTransOffset = 102;

                    ;% rtB.j12gajq3nk
                    section.data(96).logicalSrcIdx = 95;
                    section.data(96).dtTransOffset = 103;

                    ;% rtB.fp4kvwkhb2
                    section.data(97).logicalSrcIdx = 96;
                    section.data(97).dtTransOffset = 104;

                    ;% rtB.bfj5en5dwl
                    section.data(98).logicalSrcIdx = 97;
                    section.data(98).dtTransOffset = 105;

                    ;% rtB.f3zfx5i1qi
                    section.data(99).logicalSrcIdx = 98;
                    section.data(99).dtTransOffset = 106;

                    ;% rtB.e3cmaucgmt
                    section.data(100).logicalSrcIdx = 99;
                    section.data(100).dtTransOffset = 107;

                    ;% rtB.fhi3lx05bl
                    section.data(101).logicalSrcIdx = 100;
                    section.data(101).dtTransOffset = 108;

                    ;% rtB.ouzs4lmuqx
                    section.data(102).logicalSrcIdx = 101;
                    section.data(102).dtTransOffset = 109;

                    ;% rtB.eqy1xbfuno
                    section.data(103).logicalSrcIdx = 102;
                    section.data(103).dtTransOffset = 110;

                    ;% rtB.fv3y52dwhk
                    section.data(104).logicalSrcIdx = 103;
                    section.data(104).dtTransOffset = 111;

                    ;% rtB.mb425rxaxi
                    section.data(105).logicalSrcIdx = 104;
                    section.data(105).dtTransOffset = 112;

                    ;% rtB.on3vqu35sx
                    section.data(106).logicalSrcIdx = 105;
                    section.data(106).dtTransOffset = 113;

                    ;% rtB.mkrlv4bnm4
                    section.data(107).logicalSrcIdx = 106;
                    section.data(107).dtTransOffset = 114;

                    ;% rtB.j3gpdw4sxt
                    section.data(108).logicalSrcIdx = 107;
                    section.data(108).dtTransOffset = 115;

                    ;% rtB.dbe4j4gs4p
                    section.data(109).logicalSrcIdx = 108;
                    section.data(109).dtTransOffset = 116;

                    ;% rtB.ag42rst0ar
                    section.data(110).logicalSrcIdx = 109;
                    section.data(110).dtTransOffset = 117;

                    ;% rtB.i1pjnklda5
                    section.data(111).logicalSrcIdx = 116;
                    section.data(111).dtTransOffset = 120;

                    ;% rtB.kveylxgdco
                    section.data(112).logicalSrcIdx = 117;
                    section.data(112).dtTransOffset = 121;

                    ;% rtB.bxpijicezw
                    section.data(113).logicalSrcIdx = 118;
                    section.data(113).dtTransOffset = 122;

                    ;% rtB.mkgohufe3v
                    section.data(114).logicalSrcIdx = 119;
                    section.data(114).dtTransOffset = 123;

                    ;% rtB.o1n4f00fxi
                    section.data(115).logicalSrcIdx = 120;
                    section.data(115).dtTransOffset = 124;

                    ;% rtB.pkoqtgo3ru
                    section.data(116).logicalSrcIdx = 121;
                    section.data(116).dtTransOffset = 125;

                    ;% rtB.f0chc4joi3
                    section.data(117).logicalSrcIdx = 122;
                    section.data(117).dtTransOffset = 126;

                    ;% rtB.gqe5afnbdy
                    section.data(118).logicalSrcIdx = 123;
                    section.data(118).dtTransOffset = 127;

            nTotData = nTotData + section.nData;
            sigMap.sections(1) = section;
            clear section

            section.nData     = 1;
            section.data(1)  = dumData; %prealloc

                    ;% rtB.hzs2uh04g2
                    section.data(1).logicalSrcIdx = 124;
                    section.data(1).dtTransOffset = 0;

            nTotData = nTotData + section.nData;
            sigMap.sections(2) = section;
            clear section


            ;%
            ;% Non-auto Data (signal)
            ;%


        ;%
        ;% Add final counts to struct.
        ;%
        sigMap.nTotData = nTotData;



    ;%*******************
    ;% Create DWork Map *
    ;%*******************
    
        nTotData      = 0; %add to this count as we go
        nTotSects     = 7;
        sectIdxOffset = 2;

        ;%
        ;% Define dummy sections & preallocate arrays
        ;%
        dumSection.nData = -1;
        dumSection.data  = [];

        dumData.logicalSrcIdx = -1;
        dumData.dtTransOffset = -1;

        ;%
        ;% Init/prealloc dworkMap
        ;%
        dworkMap.nSections           = nTotSects;
        dworkMap.sectIdxOffset       = sectIdxOffset;
            dworkMap.sections(nTotSects) = dumSection; %prealloc
        dworkMap.nTotData            = -1;

        ;%
        ;% Auto data (rtDW)
        ;%
            section.nData     = 23;
            section.data(23)  = dumData; %prealloc

                    ;% rtDW.hprxrheipv
                    section.data(1).logicalSrcIdx = 0;
                    section.data(1).dtTransOffset = 0;

                    ;% rtDW.fa3kyx4wzc
                    section.data(2).logicalSrcIdx = 1;
                    section.data(2).dtTransOffset = 1;

                    ;% rtDW.amwiqdzhnb
                    section.data(3).logicalSrcIdx = 2;
                    section.data(3).dtTransOffset = 2;

                    ;% rtDW.odgauldpqp
                    section.data(4).logicalSrcIdx = 3;
                    section.data(4).dtTransOffset = 3;

                    ;% rtDW.ffq45mtx44
                    section.data(5).logicalSrcIdx = 4;
                    section.data(5).dtTransOffset = 4;

                    ;% rtDW.fko5kmgkv4
                    section.data(6).logicalSrcIdx = 5;
                    section.data(6).dtTransOffset = 5;

                    ;% rtDW.fqkxbyq3ut
                    section.data(7).logicalSrcIdx = 6;
                    section.data(7).dtTransOffset = 6;

                    ;% rtDW.dhjevbkvzx
                    section.data(8).logicalSrcIdx = 7;
                    section.data(8).dtTransOffset = 7;

                    ;% rtDW.jytz2gt3z0
                    section.data(9).logicalSrcIdx = 8;
                    section.data(9).dtTransOffset = 8;

                    ;% rtDW.d3rojhmrpd
                    section.data(10).logicalSrcIdx = 9;
                    section.data(10).dtTransOffset = 9;

                    ;% rtDW.ovw3xcoqp2
                    section.data(11).logicalSrcIdx = 10;
                    section.data(11).dtTransOffset = 10;

                    ;% rtDW.kara2t0mc4
                    section.data(12).logicalSrcIdx = 11;
                    section.data(12).dtTransOffset = 11;

                    ;% rtDW.geoqt2njvq
                    section.data(13).logicalSrcIdx = 12;
                    section.data(13).dtTransOffset = 12;

                    ;% rtDW.datilwe1uv
                    section.data(14).logicalSrcIdx = 13;
                    section.data(14).dtTransOffset = 13;

                    ;% rtDW.dd0rswmd4t
                    section.data(15).logicalSrcIdx = 14;
                    section.data(15).dtTransOffset = 14;

                    ;% rtDW.lddfglxdhw
                    section.data(16).logicalSrcIdx = 15;
                    section.data(16).dtTransOffset = 15;

                    ;% rtDW.ncm3zm5hoj
                    section.data(17).logicalSrcIdx = 16;
                    section.data(17).dtTransOffset = 16;

                    ;% rtDW.gwgheoas13
                    section.data(18).logicalSrcIdx = 17;
                    section.data(18).dtTransOffset = 17;

                    ;% rtDW.lm1lzdgdxr
                    section.data(19).logicalSrcIdx = 18;
                    section.data(19).dtTransOffset = 18;

                    ;% rtDW.j5dabtopgd
                    section.data(20).logicalSrcIdx = 19;
                    section.data(20).dtTransOffset = 19;

                    ;% rtDW.ilrzmnpiyv
                    section.data(21).logicalSrcIdx = 20;
                    section.data(21).dtTransOffset = 20;

                    ;% rtDW.cqnomnnw0c
                    section.data(22).logicalSrcIdx = 21;
                    section.data(22).dtTransOffset = 21;

                    ;% rtDW.bmtp0klqad
                    section.data(23).logicalSrcIdx = 22;
                    section.data(23).dtTransOffset = 22;

            nTotData = nTotData + section.nData;
            dworkMap.sections(1) = section;
            clear section

            section.nData     = 44;
            section.data(44)  = dumData; %prealloc

                    ;% rtDW.ohq3lsjal4.LoggedData
                    section.data(1).logicalSrcIdx = 23;
                    section.data(1).dtTransOffset = 0;

                    ;% rtDW.i4j4dxuntd.LoggedData
                    section.data(2).logicalSrcIdx = 24;
                    section.data(2).dtTransOffset = 2;

                    ;% rtDW.kwpa20gymm.LoggedData
                    section.data(3).logicalSrcIdx = 25;
                    section.data(3).dtTransOffset = 6;

                    ;% rtDW.kx5ay5eqjz.LoggedData
                    section.data(4).logicalSrcIdx = 26;
                    section.data(4).dtTransOffset = 10;

                    ;% rtDW.gtwgkvfkrr.LoggedData
                    section.data(5).logicalSrcIdx = 27;
                    section.data(5).dtTransOffset = 14;

                    ;% rtDW.ftxpddqw5o.LoggedData
                    section.data(6).logicalSrcIdx = 28;
                    section.data(6).dtTransOffset = 18;

                    ;% rtDW.g0z2k13e5c.LoggedData
                    section.data(7).logicalSrcIdx = 29;
                    section.data(7).dtTransOffset = 20;

                    ;% rtDW.n43ox2u3t1.LoggedData
                    section.data(8).logicalSrcIdx = 30;
                    section.data(8).dtTransOffset = 22;

                    ;% rtDW.gtiwbobrlm.LoggedData
                    section.data(9).logicalSrcIdx = 31;
                    section.data(9).dtTransOffset = 26;

                    ;% rtDW.cco0abvm2n.LoggedData
                    section.data(10).logicalSrcIdx = 32;
                    section.data(10).dtTransOffset = 28;

                    ;% rtDW.dtkgpv4uxz.LoggedData
                    section.data(11).logicalSrcIdx = 33;
                    section.data(11).dtTransOffset = 31;

                    ;% rtDW.aey5u31lbx.LoggedData
                    section.data(12).logicalSrcIdx = 34;
                    section.data(12).dtTransOffset = 33;

                    ;% rtDW.fwng4lvvau.LoggedData
                    section.data(13).logicalSrcIdx = 35;
                    section.data(13).dtTransOffset = 35;

                    ;% rtDW.h11dzsnluw.LoggedData
                    section.data(14).logicalSrcIdx = 36;
                    section.data(14).dtTransOffset = 37;

                    ;% rtDW.m34qtnmalj.LoggedData
                    section.data(15).logicalSrcIdx = 37;
                    section.data(15).dtTransOffset = 39;

                    ;% rtDW.dpsxljhuzp.LoggedData
                    section.data(16).logicalSrcIdx = 38;
                    section.data(16).dtTransOffset = 41;

                    ;% rtDW.matdy1tdy3.LoggedData
                    section.data(17).logicalSrcIdx = 39;
                    section.data(17).dtTransOffset = 42;

                    ;% rtDW.azq412n35j.LoggedData
                    section.data(18).logicalSrcIdx = 40;
                    section.data(18).dtTransOffset = 43;

                    ;% rtDW.cakujfb4xb.LoggedData
                    section.data(19).logicalSrcIdx = 41;
                    section.data(19).dtTransOffset = 46;

                    ;% rtDW.kh3eqrlac2.LoggedData
                    section.data(20).logicalSrcIdx = 42;
                    section.data(20).dtTransOffset = 47;

                    ;% rtDW.e510pci4u5.LoggedData
                    section.data(21).logicalSrcIdx = 43;
                    section.data(21).dtTransOffset = 49;

                    ;% rtDW.hitw4151ab.LoggedData
                    section.data(22).logicalSrcIdx = 44;
                    section.data(22).dtTransOffset = 51;

                    ;% rtDW.bp4eykw0vd.AQHandles
                    section.data(23).logicalSrcIdx = 45;
                    section.data(23).dtTransOffset = 52;

                    ;% rtDW.bovenmqi1n.AQHandles
                    section.data(24).logicalSrcIdx = 46;
                    section.data(24).dtTransOffset = 53;

                    ;% rtDW.crs5dztjnl.AQHandles
                    section.data(25).logicalSrcIdx = 47;
                    section.data(25).dtTransOffset = 54;

                    ;% rtDW.e5t2rc31ee.AQHandles
                    section.data(26).logicalSrcIdx = 48;
                    section.data(26).dtTransOffset = 55;

                    ;% rtDW.mmoa40glzz.AQHandles
                    section.data(27).logicalSrcIdx = 49;
                    section.data(27).dtTransOffset = 65;

                    ;% rtDW.bvuygkxhtc.AQHandles
                    section.data(28).logicalSrcIdx = 50;
                    section.data(28).dtTransOffset = 66;

                    ;% rtDW.mf2xae1npy.AQHandles
                    section.data(29).logicalSrcIdx = 51;
                    section.data(29).dtTransOffset = 67;

                    ;% rtDW.dbwufbl23w.AQHandles
                    section.data(30).logicalSrcIdx = 52;
                    section.data(30).dtTransOffset = 68;

                    ;% rtDW.orpiz44d0g.AQHandles
                    section.data(31).logicalSrcIdx = 53;
                    section.data(31).dtTransOffset = 69;

                    ;% rtDW.ih53uoy1t0.AQHandles
                    section.data(32).logicalSrcIdx = 54;
                    section.data(32).dtTransOffset = 70;

                    ;% rtDW.ect2f0tnka.AQHandles
                    section.data(33).logicalSrcIdx = 55;
                    section.data(33).dtTransOffset = 71;

                    ;% rtDW.pkrqonqp5u.AQHandles
                    section.data(34).logicalSrcIdx = 56;
                    section.data(34).dtTransOffset = 72;

                    ;% rtDW.bgemfq2tua.AQHandles
                    section.data(35).logicalSrcIdx = 57;
                    section.data(35).dtTransOffset = 73;

                    ;% rtDW.gswwaqfbot.AQHandles
                    section.data(36).logicalSrcIdx = 58;
                    section.data(36).dtTransOffset = 74;

                    ;% rtDW.mizp5nymnd.AQHandles
                    section.data(37).logicalSrcIdx = 59;
                    section.data(37).dtTransOffset = 75;

                    ;% rtDW.ikhva04gbk.AQHandles
                    section.data(38).logicalSrcIdx = 60;
                    section.data(38).dtTransOffset = 76;

                    ;% rtDW.pn4hq4ozkk.AQHandles
                    section.data(39).logicalSrcIdx = 61;
                    section.data(39).dtTransOffset = 77;

                    ;% rtDW.iqwupfikld.AQHandles
                    section.data(40).logicalSrcIdx = 62;
                    section.data(40).dtTransOffset = 83;

                    ;% rtDW.lrnl3ov5qf.AQHandles
                    section.data(41).logicalSrcIdx = 63;
                    section.data(41).dtTransOffset = 84;

                    ;% rtDW.fqt3zt3xdn.AQHandles
                    section.data(42).logicalSrcIdx = 64;
                    section.data(42).dtTransOffset = 85;

                    ;% rtDW.ea50zigag1.AQHandles
                    section.data(43).logicalSrcIdx = 65;
                    section.data(43).dtTransOffset = 86;

                    ;% rtDW.cnko5amujf.LoggedData
                    section.data(44).logicalSrcIdx = 66;
                    section.data(44).dtTransOffset = 87;

            nTotData = nTotData + section.nData;
            dworkMap.sections(2) = section;
            clear section

            section.nData     = 8;
            section.data(8)  = dumData; %prealloc

                    ;% rtDW.e40wex4pvo
                    section.data(1).logicalSrcIdx = 67;
                    section.data(1).dtTransOffset = 0;

                    ;% rtDW.oh1qqowrww
                    section.data(2).logicalSrcIdx = 68;
                    section.data(2).dtTransOffset = 1;

                    ;% rtDW.ixezhwtumm
                    section.data(3).logicalSrcIdx = 69;
                    section.data(3).dtTransOffset = 2;

                    ;% rtDW.avpjqqjd24
                    section.data(4).logicalSrcIdx = 70;
                    section.data(4).dtTransOffset = 3;

                    ;% rtDW.gdkiocucec
                    section.data(5).logicalSrcIdx = 71;
                    section.data(5).dtTransOffset = 4;

                    ;% rtDW.oolrhdhdmq
                    section.data(6).logicalSrcIdx = 72;
                    section.data(6).dtTransOffset = 5;

                    ;% rtDW.ldipnz2bdt
                    section.data(7).logicalSrcIdx = 73;
                    section.data(7).dtTransOffset = 6;

                    ;% rtDW.camyo5zuym
                    section.data(8).logicalSrcIdx = 74;
                    section.data(8).dtTransOffset = 7;

            nTotData = nTotData + section.nData;
            dworkMap.sections(3) = section;
            clear section

            section.nData     = 4;
            section.data(4)  = dumData; %prealloc

                    ;% rtDW.g23yzhoyrz
                    section.data(1).logicalSrcIdx = 75;
                    section.data(1).dtTransOffset = 0;

                    ;% rtDW.npdefkjfcm
                    section.data(2).logicalSrcIdx = 76;
                    section.data(2).dtTransOffset = 1;

                    ;% rtDW.du2ujiumnn
                    section.data(3).logicalSrcIdx = 77;
                    section.data(3).dtTransOffset = 2;

                    ;% rtDW.d14z4otzy3
                    section.data(4).logicalSrcIdx = 78;
                    section.data(4).dtTransOffset = 3;

            nTotData = nTotData + section.nData;
            dworkMap.sections(4) = section;
            clear section

            section.nData     = 8;
            section.data(8)  = dumData; %prealloc

                    ;% rtDW.gxaq1xdgdu
                    section.data(1).logicalSrcIdx = 79;
                    section.data(1).dtTransOffset = 0;

                    ;% rtDW.lozqbl1ggx
                    section.data(2).logicalSrcIdx = 80;
                    section.data(2).dtTransOffset = 1;

                    ;% rtDW.miseah5dby
                    section.data(3).logicalSrcIdx = 81;
                    section.data(3).dtTransOffset = 2;

                    ;% rtDW.aqjzi23ipz
                    section.data(4).logicalSrcIdx = 82;
                    section.data(4).dtTransOffset = 3;

                    ;% rtDW.a2kxzc4t52
                    section.data(5).logicalSrcIdx = 83;
                    section.data(5).dtTransOffset = 4;

                    ;% rtDW.amagso4rug
                    section.data(6).logicalSrcIdx = 84;
                    section.data(6).dtTransOffset = 5;

                    ;% rtDW.l0m4nljsd4
                    section.data(7).logicalSrcIdx = 85;
                    section.data(7).dtTransOffset = 6;

                    ;% rtDW.l4hdbqy4he
                    section.data(8).logicalSrcIdx = 86;
                    section.data(8).dtTransOffset = 7;

            nTotData = nTotData + section.nData;
            dworkMap.sections(5) = section;
            clear section

            section.nData     = 1;
            section.data(1)  = dumData; %prealloc

                    ;% rtDW.pjlj2hadtm
                    section.data(1).logicalSrcIdx = 87;
                    section.data(1).dtTransOffset = 0;

            nTotData = nTotData + section.nData;
            dworkMap.sections(6) = section;
            clear section

            section.nData     = 13;
            section.data(13)  = dumData; %prealloc

                    ;% rtDW.emos0ruoam
                    section.data(1).logicalSrcIdx = 88;
                    section.data(1).dtTransOffset = 0;

                    ;% rtDW.igi5qk2j1v
                    section.data(2).logicalSrcIdx = 89;
                    section.data(2).dtTransOffset = 1;

                    ;% rtDW.pzjrpevl1w
                    section.data(3).logicalSrcIdx = 90;
                    section.data(3).dtTransOffset = 2;

                    ;% rtDW.fqotav0xjm
                    section.data(4).logicalSrcIdx = 91;
                    section.data(4).dtTransOffset = 3;

                    ;% rtDW.j4y34uqjoi
                    section.data(5).logicalSrcIdx = 92;
                    section.data(5).dtTransOffset = 4;

                    ;% rtDW.k31o3jcmlw
                    section.data(6).logicalSrcIdx = 93;
                    section.data(6).dtTransOffset = 5;

                    ;% rtDW.o2i4ygmmz5
                    section.data(7).logicalSrcIdx = 94;
                    section.data(7).dtTransOffset = 6;

                    ;% rtDW.hljpt5b0da
                    section.data(8).logicalSrcIdx = 95;
                    section.data(8).dtTransOffset = 7;

                    ;% rtDW.luujo02why
                    section.data(9).logicalSrcIdx = 96;
                    section.data(9).dtTransOffset = 8;

                    ;% rtDW.goxhpsllnu
                    section.data(10).logicalSrcIdx = 97;
                    section.data(10).dtTransOffset = 9;

                    ;% rtDW.oxqfvrcqms
                    section.data(11).logicalSrcIdx = 98;
                    section.data(11).dtTransOffset = 10;

                    ;% rtDW.fdiw52kqkx
                    section.data(12).logicalSrcIdx = 99;
                    section.data(12).dtTransOffset = 11;

                    ;% rtDW.hie3syjujb
                    section.data(13).logicalSrcIdx = 100;
                    section.data(13).dtTransOffset = 12;

            nTotData = nTotData + section.nData;
            dworkMap.sections(7) = section;
            clear section


            ;%
            ;% Non-auto Data (dwork)
            ;%


        ;%
        ;% Add final counts to struct.
        ;%
        dworkMap.nTotData = nTotData;



    ;%
    ;% Add individual maps to base struct.
    ;%

    targMap.paramMap  = paramMap;
    targMap.signalMap = sigMap;
    targMap.dworkMap  = dworkMap;

    ;%
    ;% Add checksums to base struct.
    ;%


    targMap.checksum0 = 1123025869;
    targMap.checksum1 = 2487953840;
    targMap.checksum2 = 1341387358;
    targMap.checksum3 = 1669889294;

