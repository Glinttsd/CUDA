/*********************************************************************************
  *FileName:  Stencil
  *Author:  Glinttsd
  *Version:  1.0
  *Date:  2020.10.23
  *Description: 本代码利用GPU并行加速，对数组进行一个类似卷积的操作，将数组某一元素的
  *			 左右RADIUS范围内的所有元素相加，存储到另一数组里
  *Others:  数组长度N不宜太大，本示例的目的是强调share memory的合理使用。在线程过多的
  *			情况下应该分多个block进行计算，本示例只用了一个block。
**********************************************************************************/
#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include <stdio.h>
#include <malloc.h>

#define  N 16 // N不应太大(1-255)否则一个block中会有太多线程
#define  RADIUS 3

void init_vec(int* a)
{
	for (int i = 0; i < N; i++)
	{
		a[i] = i + 1;
	}
}

void func_print(int* b)
{
	for (int i = 0; i < N; i++)
		printf("%d\n", b[i]);
}

__global__ void stencil_kernel(int *in, int *out)
{
	int ID_local = threadIdx.x; //线程的本地坐标
	int ID_global = blockIdx.x * blockDim.x + threadIdx.x; //线程的全局坐标
	
	__shared__ int share_in[N + 2 * RADIUS];//申请share memory(SM)
	
	//初始化SM
	if (ID_local < RADIUS)
	{
		share_in[ID_local] = 0;
		share_in[(N + 2 * RADIUS) - ID_local] = 0;
	}
	share_in[ID_local + RADIUS] = in[ID_global];

	__syncthreads();//同步块中的每个线程，避免冲突
	
	//对数据进行操作
	int value = 0;
	for (int offset = -RADIUS; offset < RADIUS + 1; offset++)
	{
		value += share_in[ID_local + RADIUS + offset];
	}
	out[ID_global] = value;
}


int main()
{
	//在CPU申请内存空间
	int* a = (int*)malloc(sizeof(int) * N);
	int* b = (int*)malloc(sizeof(int) * N);

	//在GPU申请内存空间
	int* dev_a, *dev_b;
	cudaMalloc((void**)&dev_a, sizeof(int) * N);
	cudaMalloc((void**)&dev_b, sizeof(int) * N);

	//初始化数组
	init_vec(a);

	//将CPU中数据拷贝到GPU内存中
	cudaMemcpy(dev_a, a, N * sizeof(int), cudaMemcpyHostToDevice);

	//加载kernel函数
	stencil_kernel <<<1, N>>> (dev_a, dev_b);// 只用到一个block

	//将GPU数据拷贝到CPU中
	cudaMemcpy(b, dev_b, N * sizeof(int), cudaMemcpyDeviceToHost);

	//释放GPU内存
	cudaFree(dev_a);
	cudaFree(dev_b);

	//输出结果
	func_print(b);
	return 0;
}