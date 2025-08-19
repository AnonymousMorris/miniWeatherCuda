import netCDF4
import sys
import numpy as np

#######################################################################################
#######################################################################################
##
## validate_netcdf.py: A NetCDF validation tool that checks file integrity and performs
## 3-way comparison. Based on nccmp3.py but adds validation checks to ensure the NC
## files are valid and can be properly opened and read.
##
## python validate_netcdf.py file1.nc file2.nc file3.nc
##
#######################################################################################
#######################################################################################

failed = True

def validate_netcdf_file(filepath):
    """Validate that a NetCDF file is readable and has valid structure"""
    try:
        nc = netCDF4.Dataset(filepath, 'r')
        # Try to read basic metadata
        vars_count = len(nc.variables)
        dims_count = len(nc.dimensions)
        # Try to access at least one variable if available
        if vars_count > 0:
            var_name = list(nc.variables.keys())[0]
            var_shape = nc.variables[var_name].shape
        nc.close()
        return True, f"Valid NC file: {vars_count} variables, {dims_count} dimensions"
    except Exception as e:
        return False, f"Invalid NC file: {str(e)}"

#Complain if there aren't three arguments
if (len(sys.argv) < 4) :
    print("Usage: python validate_netcdf.py file1.nc file2.nc file3.nc")
    sys.exit(1)

# Validate all three files first
files = [sys.argv[1], sys.argv[2], sys.argv[3]]
for i, filepath in enumerate(files, 1):
    is_valid, message = validate_netcdf_file(filepath)
    print(f"File {i} ({filepath}): {message}")
    if not is_valid:
        print(f"Error: File {i} is not a valid NetCDF file. Exiting.")
        sys.exit(1)

print("\nAll files validated successfully. Proceeding with comparison...\n")

#Open the files
nc1 = netCDF4.Dataset(sys.argv[1])
nc2 = netCDF4.Dataset(sys.argv[2])
nc3 = netCDF4.Dataset(sys.argv[3])

#Print column headers
print("Var Name".ljust(20)+":  "+"|1-2|".ljust(20)+"  ,  "+"|2-3|".ljust(20)+"  ,  "+"|2-3|/|1-2|")

#Loop through all variables
for v in nc1.variables.keys() :
    #Only compare floats
    if (nc2.variables[v].dtype == np.float64 or nc2.variables[v].dtype == np.float32) :
        #Grab the variables
        a1 = nc1.variables[v][:]
        a2 = nc2.variables[v][:]
        a3 = nc3.variables[v][:]
        #Compute the absolute difference vectors
        adiff12 = abs(a2-a1)
        adiff23 = abs(a3-a2)

        #Compute relative 2-norm between files 1 & 2 and files 2 & 3
        norm12 = np.sum( adiff12**2 )
        norm23 = np.sum( adiff23**2 )
        #Assume file 1 is "truth" for the normalization
        norm_denom = np.sum( a1**2 )
        #Only normalize if this denominator is != 0
        if (norm_denom != 0) :
            norm12 = norm12 / norm_denom
            norm23 = norm23 / norm_denom

        #Compute the ratio between the 2-3 norm and the 1-2 norm
        normRatio = norm23
        #If the denom is != 0, then go ahead and compute the ratio
        if (norm12 != 0) :
            normRatio = norm23 / norm12
        else :
            #If they're both zero, then just give a ratio of "1", showing they are the same
            if (norm23 == 0) :
                normRatio = 1
            #If the 1-2 norm is zero but the 2-3 norm is not, give a very large number so the user is informed
            else :
                normRatio = 1e50

        failed = normRatio > 2
        #Only print ratios that are > 2, meaning 2-3 diff is >2x more than the 1-2 diff.
        #In the future, this should be added as a command line parameter for the user to choose.
        if failed :
            print(v.ljust(20)+":  %20.10e  ,  %20.10e  ,  %20.10e"%(norm12,norm23,norm23/norm12))

    else: 
        print("Error: Expected Variables to be numpy arrays")

nc1.close()
nc2.close()
nc3.close()
print()
if failed:
    print("FAILED")
    exit(1)
else:
    print("SUCCESS")
    exit(0)
