cmake_minimum_required(VERSION 3.0)
project(miniWeather CXX)

enable_language(CUDA)

# Enable parallel compilation
include(ProcessorCount)
ProcessorCount(N)
if(NOT N EQUAL 0)
  set(CMAKE_BUILD_PARALLEL_LEVEL ${N})
endif()

enable_testing()

include(utils.cmake)


############################################################
## Set Parameters
############################################################
if ("${NX}" STREQUAL "")
  SET(NX 100)
endif()
if ("${NZ}" STREQUAL "")
  SET(NZ 50)
endif()
if ("${SIM_TIME}" STREQUAL "")
  SET(SIM_TIME 1000)
endif()
if ("${OUT_FREQ}" STREQUAL "")
  SET(OUT_FREQ 10)
endif()
if ("${DATA_SPEC}" STREQUAL "")
  SET(DATA_SPEC DATA_SPEC_THERMAL)
endif()
SET(EXE_DEFS "-D_NX=${NX} -D_NZ=${NZ} -D_SIM_TIME=${SIM_TIME} -D_OUT_FREQ=${OUT_FREQ} -D_DATA_SPEC=${DATA_SPEC}")
SET(TEST_DEFS "-D_NX=100 -D_NZ=50 -D_SIM_TIME=400 -D_OUT_FREQ=400 -D_DATA_SPEC=DATA_SPEC_THERMAL")


############################################################
## Append CXXFLAGS
############################################################
SET(CMAKE_CXX_FLAGS "${CXXFLAGS}")


############################################################
## Compile the MPI + CUDA version 
############################################################
if (CMAKE_CUDA_COMPILER)
  add_executable(cuda miniWeather_mpi_cuda.cu)
  set_target_properties(cuda PROPERTIES 
    # COMPILE_FLAGS "${EXE_DEFS} -g -G"
    # COMPILE_FLAGS "${EXE_DEFS} -fmad=false -O3"
    COMPILE_FLAGS "${EXE_DEFS} -O3"
    CUDA_ARCHITECTURES "80")

  add_executable(cuda_test miniWeather_mpi_cuda.cu)
  set_target_properties(cuda_test PROPERTIES 
    COMPILE_FLAGS "${TEST_DEFS} -O3"
    CUDA_ARCHITECTURES "80")

  if (NOT ("${LDFLAGS}" STREQUAL "") )
    target_link_libraries(cuda      "${LDFLAGS}")
    target_link_libraries(cuda_test "${LDFLAGS}")
  endif()
  if (NOT ("${MPI_LINK_FLAGS}" STREQUAL "") )
    target_link_libraries(cuda      "${MPI_LINK_FLAGS}")
    target_link_libraries(cuda_test "${MPI_LINK_FLAGS}")
  endif()
  if ("${CUDA_LINK_FLAGS}" STREQUAL "")
    SET(CUDA_LINK_FLAGS ${CUDA_FLAGS})
  endif()
  target_link_libraries(cuda      "${CUDA_LINK_FLAGS}")
  target_link_libraries(cuda_test "${CUDA_LINK_FLAGS}")

  configure_file(check_output.sh check_output.sh COPYONLY)
  add_test(NAME CUDA_TEST COMMAND ./check_output.sh ./cuda_test 1e-13 4.5e-5 ) 
endif()

add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/cuda_test"
                 "${CMAKE_CURRENT_BINARY_DIR}/reference_tests")
