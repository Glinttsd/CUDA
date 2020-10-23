/*********************************************************************************
  *FileName:  Stencil
  *Author:  Glinttsd
  *Version:  1.0
  *Date:  2020.10.23
  *Description: ����������GPU���м��٣����������һ�����ƾ���Ĳ�����������ĳһԪ�ص�
  *			 ����RADIUS��Χ�ڵ�����Ԫ����ӣ��洢����һ������
  *Others:  ���鳤��N����̫�󣬱�ʾ����Ŀ����ǿ��share memory�ĺ���ʹ�á����̹߳����
  *			�����Ӧ�÷ֶ��block���м��㣬��ʾ��ֻ����һ��block��
**********************************************************************************/
#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include <stdio.h>
#include <malloc.h>

#define  N 16 // N��Ӧ̫��(1-255)����һ��block�л���̫���߳�
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
	int ID_local = threadIdx.x; //�̵߳ı�������
	int ID_global = blockIdx.x * blockDim.x + threadIdx.x; //�̵߳�ȫ������
	
	__shared__ int share_in[N + 2 * RADIUS];//����share memory(SM)
	
	//��ʼ��SM
	if (ID_local < RADIUS)
	{
		share_in[ID_local] = 0;
		share_in[(N + 2 * RADIUS) - ID_local] = 0;
	}
	share_in[ID_local + RADIUS] = in[ID_global];

	__syncthreads();//ͬ�����е�ÿ���̣߳������ͻ
	
	//�����ݽ��в���
	int value = 0;
	for (int offset = -RADIUS; offset < RADIUS + 1; offset++)
	{
		value += share_in[ID_local + RADIUS + offset];
	}
	out[ID_global] = value;
}


int main()
{
	//��CPU�����ڴ�ռ�
	int* a = (int*)malloc(sizeof(int) * N);
	int* b = (int*)malloc(sizeof(int) * N);

	//��GPU�����ڴ�ռ�
	int* dev_a, *dev_b;
	cudaMalloc((void**)&dev_a, sizeof(int) * N);
	cudaMalloc((void**)&dev_b, sizeof(int) * N);

	//��ʼ������
	init_vec(a);

	//��CPU�����ݿ�����GPU�ڴ���
	cudaMemcpy(dev_a, a, N * sizeof(int), cudaMemcpyHostToDevice);

	//����kernel����
	stencil_kernel <<<1, N>>> (dev_a, dev_b);// ֻ�õ�һ��block

	//��GPU���ݿ�����CPU��
	cudaMemcpy(b, dev_b, N * sizeof(int), cudaMemcpyDeviceToHost);

	//�ͷ�GPU�ڴ�
	cudaFree(dev_a);
	cudaFree(dev_b);

	//������
	func_print(b);
	return 0;
}