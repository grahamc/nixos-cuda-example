/*
 * Copyright 1993-2015 NVIDIA Corporation.  All rights reserved.
 *
 * Please refer to the NVIDIA end user license agreement (EULA) associated
 * with this source code for terms and conditions that govern your use of
 * this software. Any use, reproduction, disclosure, or distribution of
 * this software and related documentation outside the terms of the EULA
 * is strictly prohibited.
 *
 */

/*
 * This sample implements a simple task consumer using threads and streams
 * with all data in Unified Memory, and tasks consumed by both host and device
 */

// system includes
#include <cstdio>
#include <ctime>
#include <vector>
#include <algorithm>
#include <omp.h>
#include <stdlib.h>

// cuBLAS
#include <cublas_v2.h>

// utilities
#include <helper_cuda.h>

#if defined(WIN32) || defined(_WIN32) || defined(WIN64) || defined(_WIN64)
// SRAND48 and DRAND48 don't exist on windows, but these are the equivalent functions
	void srand48(long seed)
	{
		srand((unsigned int)seed);
	}
	double drand48()
	{
		return double(rand())/RAND_MAX;
	}
#endif

const char *sSDKname = "UnifiedMemoryStreams";

// simple task
template <typename T>
struct Task
{
    unsigned int size, id;
    T *data;
    T *result;
    T *vector;

    Task() : size(0), id(0), data(NULL), result(NULL), vector(NULL) {};
    Task(unsigned int s) : size(s), id(0), data(NULL), result(NULL)
    {
        // allocate unified memory -- the operation performed in this example will be a DGEMV
        checkCudaErrors(cudaMallocManaged(&data, sizeof(T)*size*size));
        checkCudaErrors(cudaMallocManaged(&result, sizeof(T)*size));
        checkCudaErrors(cudaMallocManaged(&vector, sizeof(T)*size));
        checkCudaErrors(cudaDeviceSynchronize());
    }

    ~Task()
    {
        // ensure all memory is deallocated
        checkCudaErrors(cudaDeviceSynchronize());
        checkCudaErrors(cudaFree(data));
        checkCudaErrors(cudaFree(result));
        checkCudaErrors(cudaFree(vector));
    }

    void allocate(const unsigned int s, const unsigned int unique_id)
    {
        // allocate unified memory outside of constructor
        id = unique_id;
        size = s;
        checkCudaErrors(cudaMallocManaged(&data, sizeof(T)*size*size));
        checkCudaErrors(cudaMallocManaged(&result, sizeof(T)*size));
        checkCudaErrors(cudaMallocManaged(&vector, sizeof(T)*size));
        checkCudaErrors(cudaDeviceSynchronize());

        // populate data with random elements
        for (int i=0; i<size*size; i++)
        {
            data[i] = drand48();
        }

        for (int i=0; i<size; i++)
        {
            result[i] = 0.;
            vector[i] = drand48();
        }
    }
};

// simple host dgemv: assume data is in row-major format and square
template <typename T>
void gemv(int m, int n, T alpha, T *A, T *x, T beta, T *result)
{
    // rows
    for (int i=0; i<n; i++)
    {
        result[i] *= beta;

        for (int j=0; j<n; j++)
        {
            result[i] += A[i*n+ j]*x[j];
        }
    }
}

// execute a single task on either host or device depending on size
template <typename T>
void execute(Task<T> &t, cublasHandle_t *handle, cudaStream_t *stream, int tid)
{
    if (t.size < 100)
    {
        // perform on host
        printf("Task [%d], thread [%d] executing on host (%d)\n",t.id,tid,t.size);

        // attach managed memory to a (dummy) stream to allow host access while the device is running
        checkCudaErrors(cudaStreamAttachMemAsync(stream[0], t.data, 0, cudaMemAttachHost));
        checkCudaErrors(cudaStreamAttachMemAsync(stream[0], t.vector, 0, cudaMemAttachHost));
        checkCudaErrors(cudaStreamAttachMemAsync(stream[0], t.result, 0, cudaMemAttachHost));
        // necessary to ensure Async cudaStreamAttachMemAsync calls have finished
        checkCudaErrors(cudaStreamSynchronize(stream[0]));
        // call the host operation
        gemv(t.size, t.size, 1.0, t.data, t.vector, 0.0, t.result);
    }
    else
    {
        // perform on device
        printf("Task [%d], thread [%d] executing on device (%d)\n",t.id,tid,t.size);
        double one = 1.0;
        double zero = 0.0;

        // attach managed memory to my stream
        checkCudaErrors(cublasSetStream(handle[tid+1], stream[tid+1]));
        checkCudaErrors(cudaStreamAttachMemAsync(stream[tid+1], t.data, 0, cudaMemAttachSingle));
        checkCudaErrors(cudaStreamAttachMemAsync(stream[tid+1], t.vector, 0, cudaMemAttachSingle));
        checkCudaErrors(cudaStreamAttachMemAsync(stream[tid+1], t.result, 0, cudaMemAttachSingle));
        // call the device operation
        checkCudaErrors(cublasDgemv(handle[tid+1], CUBLAS_OP_N, t.size, t.size, &one, t.data, t.size, t.vector, 1, &zero, t.result, 1));
    }
}

// populate a list of tasks with random sizes
template <typename T>
void initialise_tasks(std::vector< Task<T> > &TaskList)
{
    for (unsigned int i=0; i<TaskList.size(); i++)
    {
        // generate random size
        int size;
        size = std::max((int)(drand48()*1000.0), 64);
        TaskList[i].allocate(size, i);
    }
}

int main(int argc, char **argv)
{
    // set device
    cudaDeviceProp device_prop;
    int dev_id = findCudaDevice(argc, (const char **) argv);
    checkCudaErrors(cudaGetDeviceProperties(&device_prop, dev_id));

    if (!device_prop.managedMemory) { 
        // This samples requires being run on a device that supports Unified Memory
        fprintf(stderr, "Unified Memory not supported on this device\n");

        // cudaDeviceReset causes the driver to clean up all state. While
        // not mandatory in normal operation, it is good practice.  It is also
        // needed to ensure correct operation when the application is being
        // profiled. Calling cudaDeviceReset causes all profile data to be
        // flushed before the application exits
        cudaDeviceReset();
        exit(EXIT_WAIVED);
    }

    if (device_prop.computeMode == cudaComputeModeExclusive || device_prop.computeMode == cudaComputeModeProhibited)
    {
        // This sample requires being run with a default or process exclusive mode
        fprintf(stderr, "This sample requires a device in either default or process exclusive mode\n");

        // cudaDeviceReset causes the driver to clean up all state. While
        // not mandatory in normal operation, it is good practice.  It is also
        // needed to ensure correct operation when the application is being
        // profiled. Calling cudaDeviceReset causes all profile data to be
        // flushed before the application exits
        cudaDeviceReset();
        exit(EXIT_WAIVED);
    }

    // randomise task sizes
    int seed = time(NULL);
    srand48(seed);

    // set number of threads
    const int nthreads = 4;
    omp_set_num_threads(nthreads);
    // number of streams = number of threads
    cudaStream_t *streams = new cudaStream_t[nthreads+1];
    cublasHandle_t *handles = new cublasHandle_t[nthreads+1];

    for (int i=0; i<nthreads+1; i++)
    {
        checkCudaErrors(cudaStreamCreate(&streams[i]));
        checkCudaErrors(cublasCreate(&handles[i]));
    }

    // create list of N tasks
    unsigned int N = 40;
    std::vector<Task<double> > TaskList(N);
    initialise_tasks(TaskList);

    printf("Executing tasks on host / device\n");
    // run through all tasks using threads and streams
    unsigned int i;
    #pragma omp parallel for schedule(dynamic)

    for (i=0; i<TaskList.size(); i++)
    {
        checkCudaErrors(cudaSetDevice(dev_id));
        int tid = omp_get_thread_num();
        execute(TaskList[i], handles, streams, tid);
    }

    cudaDeviceSynchronize();

    // Destroy CUDA Streams, cuBlas handles
    for (int i=0; i<nthreads+1; i++)
    {
        cudaStreamDestroy(streams[i]);
        cublasDestroy(handles[i]);
    }

    // Free TaskList
    std::vector< Task<double> >().swap(TaskList);

    // cudaDeviceReset causes the driver to clean up all state. While
    // not mandatory in normal operation, it is good practice.  It is also
    // needed to ensure correct operation when the application is being
    // profiled. Calling cudaDeviceReset causes all profile data to be
    // flushed before the application exits
    cudaDeviceReset();
    printf("All Done!\n");
    exit(EXIT_SUCCESS);
}

