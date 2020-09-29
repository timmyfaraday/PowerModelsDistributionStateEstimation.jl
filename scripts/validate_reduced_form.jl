##NB scaling tips: https://projects.coin-or.org/Ipopt/wiki/HintsAndTricks#Scalingoftheoptimizationproblem
##NB scaling tips: https://www.gams.com/latest/docs/S_CONOPT.html#CONOPT_SCALING


using PowerModelsDSSE, PowerModelsDistribution, Ipopt
using PowerModels, JuMP

_PMD = PowerModelsDistribution
_PMs = PowerModels
_PMS = PowerModelsDSSE

################################################################################
# Input data
ntw, fdr  = 1,1
rm_transfo = true
rd_lines   = true

season = "summer"
time   = 228
elm    = ["load", "pv"]
pfs    = [0.95, 0.90]

################################################################################
# Set measurement path
msr_path = joinpath(BASE_DIR,"test/data/enwl/measurements/temp.csv")

# Set solve
solver = JuMP.optimizer_with_attributes(Ipopt.Optimizer,"max_cpu_time"=>180.0,
                                                        "tol"=>1e-5,
                                                        "print_level"=>3)
                                                        #"fixed_variable_treatment"=>"make_constraint")

# Load the data
data = _PMD.parse_file(_PMS.get_enwl_dss_path(ntw, fdr),data_model=_PMD.ENGINEERING);
if rm_transfo _PMS.rm_enwl_transformer!(data) end
if rd_lines   _PMS.reduce_enwl_lines_eng!(data) end

# Insert the ENWL load profiles
_PMS.insert_profiles!(data, season, elm, pfs, t = time)

# Transform data model
#data = _PMD.parse_file("C:\\Users\\mvanin\\.julia\\dev\\PowerModelsDSSE\\test\\data\\extra\\networks\\case3_unbalanced.dss")
data = _PMD.transform_data_model(data)

data_model = _PMD.IVRPowerModel#_PMs.ACPPowerModel
pf_result= _PMD.run_mc_pf(data, data_model, solver)

_PMS.write_measurements!(data_model, data, pf_result, msr_path, exclude = ["vi","vr"])

# read-in measurement data and set initial values
_PMS.add_measurements!(data, msr_path, actual_meas = true)
_PMS.add_voltage_measurement!(data, pf_result, 0.005)
_PMS.assign_start_to_variables!(data)
_PMS.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )

# Solve the power flow
data["se_settings"] = Dict{String,Any}("estimation_criterion" => "rwlav", "weight_rescaler" => 100)
se_result_acr = PowerModelsDSSE.run_acr_mc_se(data, optimizer_with_attributes(Ipopt.Optimizer, "max_cpu_time"=>180.0, "tol"=>1e-8))#, "fixed_variable_treatment"=>"make_parameter"))
delta, max_err, avg = _PMS.calculate_voltage_magnitude_error(se_result_acr, pf_result)

se_result_ivr = PowerModelsDSSE.run_ivr_mc_se(data, optimizer_with_attributes(Ipopt.Optimizer, "max_cpu_time"=>180.0, "tol"=>1e-8, "fixed_variable_treatment"=>"make_constraint"))
delta, max_err, avg = _PMS.calculate_voltage_magnitude_error(se_result_ivr, pf_result)

se_result_acp = PowerModelsDSSE.run_acp_red_mc_se(data, optimizer_with_attributes(Ipopt.Optimizer,"max_cpu_time"=>180.0, "tol"=>1e-8))#, "fixed_variable_treatment"=>"make_parameter"))
delta, max_err, avg = _PMS.calculate_voltage_magnitude_error(se_result_acp, pf_result)

se_result_lin = PowerModelsDSSE.run_linear_mc_se(data, optimizer_with_attributes(Ipopt.Optimizer,"max_cpu_time"=>180.0, "tol"=>1e-8))
delta, max_err, avg = _PMS.calculate_voltage_magnitude_error(se_result_lin, pf_result)
