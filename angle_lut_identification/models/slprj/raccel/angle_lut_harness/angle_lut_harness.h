#ifndef angle_lut_harness_h_
#define angle_lut_harness_h_
#ifndef angle_lut_harness_COMMON_INCLUDES_
#define angle_lut_harness_COMMON_INCLUDES_
#include <stdlib.h>
#include "sl_AsyncioQueue/AsyncioQueueCAPI.h"
#include "rtwtypes.h"
#include "sigstream_rtw.h"
#include "simtarget/slSimTgtSigstreamRTW.h"
#include "simtarget/slSimTgtSlioCoreRTW.h"
#include "simtarget/slSimTgtSlioClientsRTW.h"
#include "simtarget/slSimTgtSlioSdiRTW.h"
#include "simstruc.h"
#include "fixedpoint.h"
#include "raccel.h"
#include "slsv_diagnostic_codegen_c_api.h"
#include "rt_logging_simtarget.h"
#include "rt_nonfinite.h"
#include "math.h"
#include "dt_info.h"
#include "ext_work.h"
#endif
#include "angle_lut_harness_types.h"
#include <string.h>
#include <stddef.h>
#include "rtw_modelmap_simtarget.h"
#include "rt_defines.h"
#include "rtGetInf.h"
#define MODEL_NAME angle_lut_harness
#define NSAMPLE_TIMES (8) 
#define NINPUTS (0)       
#define NOUTPUTS (0)     
#define NBLOCKIO (125) 
#define NUM_ZC_EVENTS (0) 
#ifndef NCSTATES
#define NCSTATES (4)   
#elif NCSTATES != 4
#error Invalid specification of NCSTATES defined in compiler command
#endif
#ifndef rtmGetDataMapInfo
#define rtmGetDataMapInfo(rtm) (*rt_dataMapInfoPtr)
#endif
#ifndef rtmSetDataMapInfo
#define rtmSetDataMapInfo(rtm, val) (rt_dataMapInfoPtr = &val)
#endif
#ifndef IN_RACCEL_MAIN
#endif
typedef struct { real_T pmwrvmuv2z ; real_T abtahjutxs ; real_T djegpsthsy ;
real_T k1gznu2cip ; real_T a0zjwtlk4t ; real_T hmznkt13gh ; real_T pkclptk1iu
; real_T bva1copsfh ; real_T kmrdohh114 ; real_T lnib30af4p ; real_T
j0yc5f3kku ; real_T b3jdreufcl ; real_T ku4jk3u1b1 ; real_T p50nhc4qqf ;
real_T itaesr4vi5 ; real_T kohbaqjau1 ; real_T ipp4rrhurt ; real_T iygzcfg52o
; real_T njqjiipllc ; real_T a2vdpdjjhp ; real_T bmgyv20kuq ; real_T
mtlkklsgi2 ; real_T fgydxbqcob ; real_T k3xqxyxmut ; real_T kss5c3pzf2 ;
real_T nw2r1p4typ [ 3 ] ; real_T bpzykzheeg [ 3 ] ; real_T lvdjxazx04 ;
real_T pbjw4qgbfo ; real_T avn1p5wdq4 ; real_T f1e2elmt3s ; real_T dy45qiahhv
; real_T njytyfycdb ; real_T pg4y2334si [ 3 ] ; real_T cvfrgx4lmu ; real_T
o0zh4dpwof ; real_T apfmkwq5cx ; real_T nsr2koyppz ; real_T ah2f3obaf2 ;
real_T poc05a2t00 ; real_T kjpxk43vb5 ; real_T kj1et5qiw3 ; real_T dis1gyghp5
; real_T iiu52do3gh ; real_T ja2usbfqvp ; real_T ocsbq5uu0u ; real_T
phjxq1gpwe ; real_T bqzlafhwzj ; real_T ohazbdfvqd ; real_T eyl5olnvxu ;
real_T cvaq3eiog1 ; real_T ps50vu2w2e ; real_T nccfrl32mm [ 3 ] ; real_T
aq3z3j00nc ; real_T i5s0x2u0ry ; real_T ln5hdszlm0 ; real_T dygndsrxsu ;
real_T lopwn0zgm3 ; real_T ih4lvzhbj2 ; real_T fdad4czr4f ; real_T eod0a04v3n
; real_T aa2tdapnrf ; real_T jg303qa15q ; real_T ibhfc1kvps ; real_T
fxc14bmc3y ; real_T jdef0f5arc ; real_T mx2i5f5vhu ; real_T box5mhqznz ;
real_T ke5b3yiry1 ; real_T jxxvyc5xpz ; real_T al1ilorn2w ; real_T bljwlt1rov
; real_T cjrqr42n2b ; real_T m0vdook5kv ; real_T okzfq3hfot ; real_T
eglcazss1c ; real_T nj04wgaqgx ; real_T khhsrkvjcp ; real_T dwlbdu3dqb ;
real_T o5p1bykpmb ; real_T oat5lyyojj ; real_T cluwvyj2v0 ; real_T inve0zctyf
; real_T bflux0vfd3 ; real_T o0raraegud ; real_T pojhuauetl ; real_T
d1qa04zhcn ; real_T cuiqpgxqvu ; real_T dax1enud2z ; real_T lq0la1f51o ;
real_T ohpe41w4s1 ; real_T alxkk0ezfw ; real_T gfb5kery4u ; real_T fvk0nxl0zm
; real_T ippnl13plf ; real_T j12gajq3nk ; real_T fp4kvwkhb2 ; real_T
bfj5en5dwl ; real_T f3zfx5i1qi ; real_T e3cmaucgmt ; real_T fhi3lx05bl ;
real_T ouzs4lmuqx ; real_T eqy1xbfuno ; real_T fv3y52dwhk ; real_T mb425rxaxi
; real_T on3vqu35sx ; real_T mkrlv4bnm4 ; real_T j3gpdw4sxt ; real_T
dbe4j4gs4p ; real_T ag42rst0ar [ 3 ] ; real_T i1pjnklda5 ; real_T kveylxgdco
; real_T bxpijicezw ; real_T mkgohufe3v ; real_T o1n4f00fxi ; real_T
pkoqtgo3ru ; real_T f0chc4joi3 ; real_T gqe5afnbdy ; boolean_T hzs2uh04g2 ; }
B ; typedef struct { real_T hprxrheipv ; real_T fa3kyx4wzc ; real_T
amwiqdzhnb ; real_T odgauldpqp ; real_T ffq45mtx44 ; real_T fko5kmgkv4 ;
real_T fqkxbyq3ut ; real_T dhjevbkvzx ; real_T jytz2gt3z0 ; real_T d3rojhmrpd
; real_T ovw3xcoqp2 ; real_T kara2t0mc4 ; real_T geoqt2njvq ; real_T
datilwe1uv ; real_T dd0rswmd4t ; real_T lddfglxdhw ; real_T ncm3zm5hoj ;
real_T gwgheoas13 ; real_T lm1lzdgdxr ; real_T j5dabtopgd ; real_T ilrzmnpiyv
; real_T cqnomnnw0c ; real_T bmtp0klqad ; struct { void * LoggedData [ 2 ] ;
} ohq3lsjal4 ; struct { void * LoggedData [ 4 ] ; } i4j4dxuntd ; struct {
void * LoggedData [ 4 ] ; } kwpa20gymm ; struct { void * LoggedData [ 4 ] ; }
kx5ay5eqjz ; struct { void * LoggedData [ 4 ] ; } gtwgkvfkrr ; struct { void
* LoggedData [ 2 ] ; } ftxpddqw5o ; struct { void * LoggedData [ 2 ] ; }
g0z2k13e5c ; struct { void * LoggedData [ 4 ] ; } n43ox2u3t1 ; struct { void
* LoggedData [ 2 ] ; } gtiwbobrlm ; struct { void * LoggedData [ 3 ] ; }
cco0abvm2n ; struct { void * LoggedData [ 2 ] ; } dtkgpv4uxz ; struct { void
* LoggedData [ 2 ] ; } aey5u31lbx ; struct { void * LoggedData [ 2 ] ; }
fwng4lvvau ; struct { void * LoggedData [ 2 ] ; } h11dzsnluw ; struct { void
* LoggedData [ 2 ] ; } m34qtnmalj ; struct { void * LoggedData ; } dpsxljhuzp
; struct { void * LoggedData ; } matdy1tdy3 ; struct { void * LoggedData [ 3
] ; } azq412n35j ; struct { void * LoggedData ; } cakujfb4xb ; struct { void
* LoggedData [ 2 ] ; } kh3eqrlac2 ; struct { void * LoggedData [ 2 ] ; }
e510pci4u5 ; struct { void * LoggedData ; } hitw4151ab ; struct { void *
AQHandles ; } bp4eykw0vd ; struct { void * AQHandles ; } bovenmqi1n ; struct
{ void * AQHandles ; } crs5dztjnl ; struct { void * AQHandles [ 10 ] ; }
e5t2rc31ee ; struct { void * AQHandles ; } mmoa40glzz ; struct { void *
AQHandles ; } bvuygkxhtc ; struct { void * AQHandles ; } mf2xae1npy ; struct
{ void * AQHandles ; } dbwufbl23w ; struct { void * AQHandles ; } orpiz44d0g
; struct { void * AQHandles ; } ih53uoy1t0 ; struct { void * AQHandles ; }
ect2f0tnka ; struct { void * AQHandles ; } pkrqonqp5u ; struct { void *
AQHandles ; } bgemfq2tua ; struct { void * AQHandles ; } gswwaqfbot ; struct
{ void * AQHandles ; } mizp5nymnd ; struct { void * AQHandles ; } ikhva04gbk
; struct { void * AQHandles [ 6 ] ; } pn4hq4ozkk ; struct { void * AQHandles
; } iqwupfikld ; struct { void * AQHandles ; } lrnl3ov5qf ; struct { void *
AQHandles ; } fqt3zt3xdn ; struct { void * AQHandles ; } ea50zigag1 ; struct
{ void * LoggedData [ 4 ] ; } cnko5amujf ; int32_T e40wex4pvo ; int32_T
oh1qqowrww ; int32_T ixezhwtumm ; int32_T avpjqqjd24 ; int32_T gdkiocucec ;
int32_T oolrhdhdmq ; int32_T ldipnz2bdt ; int32_T camyo5zuym ; uint32_T
g23yzhoyrz ; uint32_T npdefkjfcm ; uint32_T du2ujiumnn ; uint32_T d14z4otzy3
; int_T gxaq1xdgdu ; int_T lozqbl1ggx ; int_T miseah5dby ; int_T aqjzi23ipz ;
int_T a2kxzc4t52 ; int_T amagso4rug ; int_T l0m4nljsd4 ; int_T l4hdbqy4he ;
uint8_T pjlj2hadtm ; boolean_T emos0ruoam ; boolean_T igi5qk2j1v ; boolean_T
pzjrpevl1w ; boolean_T fqotav0xjm ; boolean_T j4y34uqjoi ; boolean_T
k31o3jcmlw ; boolean_T o2i4ygmmz5 ; boolean_T hljpt5b0da ; boolean_T
luujo02why ; boolean_T goxhpsllnu ; boolean_T oxqfvrcqms ; boolean_T
fdiw52kqkx ; boolean_T hie3syjujb ; } DW ; typedef struct { real_T atnaot4c0c
; real_T pyg12znhss ; real_T mqrldzc4uq ; real_T fhcw15zwfo ; } X ; typedef
int_T PeriodicIndX [ 1 ] ; typedef real_T PeriodicRngX [ 2 ] ; typedef struct
{ real_T atnaot4c0c ; real_T pyg12znhss ; real_T mqrldzc4uq ; real_T
fhcw15zwfo ; } XDot ; typedef struct { boolean_T atnaot4c0c ; boolean_T
pyg12znhss ; boolean_T mqrldzc4uq ; boolean_T fhcw15zwfo ; } XDis ; typedef
struct { real_T atnaot4c0c ; real_T pyg12znhss ; real_T mqrldzc4uq ; real_T
fhcw15zwfo ; } CStateAbsTol ; typedef struct { real_T atnaot4c0c ; real_T
pyg12znhss ; real_T mqrldzc4uq ; real_T fhcw15zwfo ; } CXPtMin ; typedef
struct { real_T atnaot4c0c ; real_T pyg12znhss ; real_T mqrldzc4uq ; real_T
fhcw15zwfo ; } CXPtMax ; typedef struct { real_T o3xfujwf23 ; real_T
kxwnmeslu1 ; real_T b3pbh3upyn ; real_T nmxbkl03o4 ; real_T c5zh4m5pgx ;
real_T ok4xlsapeh ; real_T prle1342iv ; real_T b103zlgf2m ; real_T j3wzagf5k4
; real_T ppzqymrzwq ; real_T mqyvn2kzyq ; real_T gjg35scpd3 ; real_T
dabqy2ajmw ; real_T epdjndzhms ; real_T coepgzsc1n ; real_T aj4cj2foby ;
real_T lzcdrkestc ; real_T mz4b4wmsme ; real_T kqv3f04q1c ; real_T n0544h2tkv
; real_T n02gbw32fr ; } ZCV ; typedef struct { rtwCAPI_ModelMappingInfo mmi ;
} DataMapInfo ; struct P_ { real_T B ; real_T BW_I ; real_T BW_speed ; real_T
J ; real_T Ld ; real_T Lq ; real_T Rs ; real_T T_ident ; real_T Vdc ; real_T
adc_current_gain ; real_T adc_current_lsb_A ; real_T adc_current_offset_a_A ;
real_T adc_current_offset_b_A ; real_T adc_current_offset_c_A ; real_T
adc_current_range_A ; real_T encoder_counts_per_rev ; real_T
encoder_error_bias_m_rad ; real_T encoder_speed_lsb_radps ; real_T
encoder_speed_offset_radps ; real_T encoder_theta_offset_rad ; real_T
inverter_voltage_drop_V ; real_T pn ; real_T psif ; real_T pwm_deadtime_s ;
real_T pwm_max_duty ; real_T pwm_min_duty ; real_T pwm_min_pulse_duty ;
real_T stage1_load_torque_Nm ; real_T stage1_overmod_epsilon ; real_T
stage1_speed_target_rpm ; real_T theta0_e_rad ; uint32_T encoder_noise_seed ;
uint32_T stage1_current_noise_seed ; uint8_T encoder_error_mode ; uint8_T
sensor_mode ; real_T PIDController1_InitialConditionForIntegrator ; real_T
PIDController2_InitialConditionForIntegrator ; real_T
PIDController_InitialConditionForIntegrator ; real_T
PIDController_LowerIntegratorSaturationLimit ; real_T
PIDController2_LowerSaturationLimit ; real_T
PIDController_UpperIntegratorSaturationLimit ; real_T
PIDController2_UpperSaturationLimit ; real_T DiscreteRateLimiter2_Vinit ;
real_T DiscreteRateLimiter_Vinit ; real_T SurfaceMountPMSM_idq0 [ 2 ] ;
real_T SurfaceMountPMSM_mechanical [ 3 ] ; real_T SurfaceMountPMSM_omega_init
; real_T RepeatingSequence_rep_seq_y [ 3 ] ; real_T
SurfaceMountPMSM_theta_init ; real_T DataStoreMemory_InitialValue ; real_T
DiscreteTimeIntegrator_gainval ; real_T DiscreteTimeIntegrator_IC ; real_T
Constant_Value ; real_T Current_Sensing_ADC_Latency_Ia_InitialCondition ;
real_T Current_Sensing_ADC_Latency_Ib_InitialCondition ; real_T
Current_Sensing_ADC_Latency_Ic_InitialCondition ; real_T
Position_Sensing_Encoder_Latency_Theta_InitialCondition ; real_T
Integrator_gainval ; real_T Int_UpperSat ; real_T Int_LowerSat ; real_T
SpeedSetpointRPM2_Time ; real_T SpeedSetpointRPM2_Y0 ; real_T
Saturation_UpperSat ; real_T Saturation_LowerSat ; real_T u_Gain ; real_T
Position_Sensing_Encoder_Latency_Wm_InitialCondition ; real_T
Integrator_gainval_jrco2bwd10 ; real_T Integrator_UpperSat ; real_T
Integrator_LowerSat ; real_T Integrator_UpperSat_fnb5xkuneo ; real_T
Integrator_LowerSat_nku0pa42gn ; real_T Integrator_gainval_fm3inckqoz ;
real_T UnitDelay3_InitialCondition ; real_T UnitDelay1_InitialCondition ;
real_T UnitDelay2_InitialCondition ; real_T Saturation2_UpperSat ; real_T
Saturation2_LowerSat ; real_T Gain_Gain ; real_T Gain2_Gain ; real_T
Gain3_Gain ; real_T Gain1_Gain ; real_T Gain4_Gain ; real_T
SpeedSetpointRPM_Time ; real_T SpeedSetpointRPM_Y0 ; real_T
Saturation_UpperSat_ngwwjyhsfd ; real_T Saturation_LowerSat_f5gxnsbbt2 ;
real_T Inverter_Nonideal_Gain ; real_T Gain_Gain_bfdvzkemvr ; real_T
Gain1_Gain_f4yqqgp53n ; real_T Gain4_Gain_cbzrmf0dwt ; real_T
Gain2_Gain_apsi0kf2uv ; real_T Gain3_Gain_aqc1lmstlp ; real_T
Gain1_Gain_kezbkczt35 ; real_T current_noise_a_Mean ; real_T
current_noise_a_StdDev ; real_T current_noise_b_Mean ; real_T
current_noise_b_StdDev ; real_T current_noise_c_Mean ; real_T
current_noise_c_StdDev ; real_T Encoder_Angle_Noise_Mean ; real_T
Encoder_Angle_Noise_StdDev ; real_T Control_Compute_Delay_Vd_InitialCondition
; real_T Control_Compute_Delay_Vq_InitialCondition ; real_T
Gain2_Gain_bfibyfcm43 ; real_T LookUpTable1_bp01Data [ 3 ] ; real_T
Gain5_Gain ; real_T UnitDelay6_InitialCondition ; real_T
UnitDelay4_InitialCondition ; real_T Constant_Value_epnbynriee ; real_T
Switch_Threshold ; real_T Constant_Value_hqnvu24bt3 ; real_T Constant1_Value
; real_T Constant11_Value ; real_T Constant12_Value ; real_T Constant6_Value
; real_T Mechanical_Wrap_Modulus_Value ; real_T Zero_Error_Value ; real_T
Constant_Value_nfrdqc41td ; real_T Constant1_Value_kb5t55ka4c ; real_T
Constant3_Value ; real_T Constant5_Value ; real_T Constant1_Value_gwaqkxkpzi
; real_T Constant_Value_nkd0bfvul3 [ 2 ] ; real_T Constant2_Value ; real_T
Constant1_Value_fal53opp3n ; real_T Constant_Value_hxwns5f3a4 [ 2 ] ; real_T
Constant1_Value_dsldruknvq ; real_T Constant_Value_ltzat0eviz [ 2 ] ; real_T
Constant1_Value_cnxhsvnkpf ; real_T Constant2_Value_ixdnz3zgzg ; real_T
Constant1_Value_ime35ehw4h [ 2 ] ; real_T Constant2_Value_dp504jpcdx ; real_T
Constant1_Value_kqqdla0atg ; real_T Constant_Value_ddd44ptvyk [ 2 ] ; real_T
Constant1_Value_ootv1z4abu ; real_T Constant_Value_k2kkxajxsy [ 2 ] ; real_T
Constant1_Value_iplzjv30is ; real_T Constant2_Value_j21pxnnccw ; real_T
Constant_Value_au2sfpopuq ; real_T Constant1_Value_cdkymhk2bj [ 2 ] ; real_T
Constant2_Value_afxbs1y1pp ; real_T Constant1_Value_njijylfm1i [ 2 ] ; real_T
Constant2_Value_dd1sscqjpw ; uint8_T Select_Error_Mode_Threshold ; uint8_T
Select_Sensor_Mode_Mechanical_Threshold ; uint8_T
Select_Sensor_Mode_Error_Threshold ; uint8_T
Select_Sensor_Mode_Electrical_Threshold ; uint8_T
Select_Off_Or_Fixed_Threshold ; } ; extern const char_T *
RT_MEMORY_ALLOCATION_ERROR ; extern B rtB ; extern X rtX ; extern DW rtDW ;
extern P rtP ; extern mxArray * mr_angle_lut_harness_GetDWork ( ) ; extern
void mr_angle_lut_harness_SetDWork ( const mxArray * ssDW ) ; extern mxArray
* mr_angle_lut_harness_GetSimStateDisallowedBlocks ( ) ; extern const
rtwCAPI_ModelMappingStaticInfo * angle_lut_harness_GetCAPIStaticMap ( void )
; extern SimStruct * const rtS ; extern DataMapInfo * rt_dataMapInfoPtr ;
extern rtwCAPI_ModelMappingInfo * rt_modelMapInfoPtr ; void MdlOutputs ( int_T
tid ) ; void MdlOutputsParameterSampleTime ( int_T tid ) ; void MdlUpdate ( int_T tid ) ; void MdlTerminate ( void ) ; void MdlInitializeSizes ( void ) ; void MdlInitializeSampleTimes ( void ) ; SimStruct * raccel_register_model ( ssExecutionInfo * executionInfo ) ;
#endif
