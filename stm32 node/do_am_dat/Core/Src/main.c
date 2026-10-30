/* USER CODE BEGIN Header */
/**
  ******************************************************************************
  * @file           : main.c
  * @brief          : Node 4 - Soil Moisture Sensor - LoRa Gateway Protocol
  ******************************************************************************
  */
/* USER CODE END Header */
/* Includes ------------------------------------------------------------------*/
#include "main.h"

/* Private includes ----------------------------------------------------------*/
/* USER CODE BEGIN Includes */
#include "stdarg.h"
#include "string.h"
#include "stdio.h"
/* USER CODE END Includes */

/* Private typedef -----------------------------------------------------------*/
/* USER CODE BEGIN PTD */

/* USER CODE END PTD */

/* Private define ------------------------------------------------------------*/
/* USER CODE BEGIN PD */
#define NODE_ID  4   // <-- Node 4 (Do am dat)
/* USER CODE END PD */

/* Private macro -------------------------------------------------------------*/
/* USER CODE BEGIN PM */

/* USER CODE END PM */

/* Private variables ---------------------------------------------------------*/
ADC_HandleTypeDef hadc1;

UART_HandleTypeDef huart1;
UART_HandleTypeDef huart2;

/* USER CODE BEGIN PV */
extern ADC_HandleTypeDef hadc1; // Khai bao bo ADC1
/* USER CODE END PV */

/* Private function prototypes -----------------------------------------------*/
void SystemClock_Config(void);
static void MX_GPIO_Init(void);
static void MX_ADC1_Init(void);
static void MX_USART1_UART_Init(void);
static void MX_USART2_UART_Init(void);
/* USER CODE BEGIN PFP */
char buff[60];
void mPrint(const char* format, ...){
    va_list args;
    va_start(args, format);
    vsnprintf(buff, sizeof(buff), format, args);
    va_end(args);
    HAL_UART_Transmit(&huart1, (uint8_t*)buff, strlen(buff), 1000);
}

uint16_t Read_Soil_Moisture_ADC(void);
uint8_t Convert_To_Percentage(uint16_t adc_val);
/* USER CODE END PFP */

/* Private user code ---------------------------------------------------------*/
/* USER CODE BEGIN 0 */
// Ham doc gia tri ADC thu tu cam bien
uint16_t Read_Soil_Moisture_ADC(void) {
    uint16_t adc_value = 0;
    
    // Khoi dong bo ADC
    HAL_ADC_Start(&hadc1);
    
    // Cho qua trinh chuyen doi hoan tat (Timeout 100ms)
    if (HAL_ADC_PollForConversion(&hadc1, 100) == HAL_OK) {
        adc_value = HAL_ADC_GetValue(&hadc1);
    }
    
    HAL_ADC_Stop(&hadc1);
    
    return adc_value;
}

// Ham chuyen doi gia tri ADC sang phan tram (%)
uint8_t Convert_To_Percentage(uint16_t adc_val) {
    uint16_t adc_dry = 4050; // Khi de ngoai khong khi (Kho)
    uint16_t adc_wet = 1500; // Khi ngam vao nuoc (Uot)
    
    int percent = 0;

    if (adc_val > adc_dry) adc_val = adc_dry;
    if (adc_val < adc_wet) adc_val = adc_wet;
    
    percent = 100 - ((adc_val - adc_wet) * 100) / (adc_dry - adc_wet);
    
    return (uint8_t)percent;
}

/* ---------- Bien phuc vu nhan lenh tu Gateway qua UART2 (LoRa) ---------- */
uint8_t rx_byte;          // Nhan tung byte mot qua ngat
char    rx_buffer[20];    // Buffer rap chuoi lenh (VD: "GET_N4")
uint8_t rx_index  = 0;
uint8_t cmd_ready = 0;    // Co bao hieu da nhan xong mot lenh

char    lora_tx_buffer[30]; // Buffer gui phan hoi
/* USER CODE END 0 */

/**
  * @brief  The application entry point.
  * @retval int
  */
int main(void)
{

  /* USER CODE BEGIN 1 */

  /* USER CODE END 1 */

  HAL_Init();

  /* USER CODE BEGIN Init */

  /* USER CODE END Init */

  SystemClock_Config();

  /* USER CODE BEGIN SysInit */

  /* USER CODE END SysInit */

  MX_GPIO_Init();
  MX_ADC1_Init();
  MX_USART1_UART_Init();
  MX_USART2_UART_Init();
  /* USER CODE BEGIN 2 */
  // Bat ngat UART2 de lang nghe lenh tu Gateway
  HAL_UART_Receive_IT(&huart2, &rx_byte, 1);
  mPrint("Node %d (Soil Moisture) Ready. Listening for Gateway...\r\n", NODE_ID);
  /* USER CODE END 2 */

  /* Infinite loop */
  /* USER CODE BEGIN WHILE */
  while (1)
  {
      // Neu co lenh gui den tu Gateway
      if (cmd_ready == 1)
      {
          cmd_ready = 0; // Tat co de tranh xu ly lap lai

          // Tao chuoi lenh mong doi (Node 4 mong nhan "GET_N4")
          char expected_cmd[12];
          sprintf(expected_cmd, "GET_N%d", NODE_ID);

          // Kiem tra lenh co dung ten minh khong (dung strstr de an toan)
          if (strstr(rx_buffer, expected_cmd) != NULL)
          {
              mPrint("Gateway goi: %s. Dang doc cam bien...\r\n", rx_buffer);

              // Doc cam bien ADC
              uint16_t adcValue = Read_Soil_Moisture_ADC();
              uint8_t moisture_percent = Convert_To_Percentage(adcValue);

              // Dong goi du lieu va gui tra qua UART2 (LoRa)
              // Dinh dang: N4,<moisture_percent>\n
              sprintf(lora_tx_buffer, "N%d,%d\n", NODE_ID, moisture_percent);
              HAL_StatusTypeDef tx_status = HAL_UART_Transmit(&huart2, (uint8_t*)lora_tx_buffer, strlen(lora_tx_buffer), 1000);
if (tx_status != HAL_OK) {
    mPrint("Loi truyen UART2: %d\r\n", tx_status);
}
              
              mPrint("ADC: %d -> Do am dat: %d%%\r\n", adcValue, moisture_percent);
              mPrint("Da gui: %s\r\n", lora_tx_buffer);
          }
          else
          {
              mPrint("Bo qua lenh: %s (Khong phai toi)\r\n", rx_buffer);
          }

          // Reset buffer chuan bi don lenh tiep theo
          rx_index = 0;
          memset(rx_buffer, 0, sizeof(rx_buffer));
      }

      // STM32 co the lam viec khac o day
    /* USER CODE END WHILE */

    /* USER CODE BEGIN 3 */
  }
  /* USER CODE END 3 */
}

/**
  * @brief System Clock Configuration
  * @retval None
  */
void SystemClock_Config(void)
{
  RCC_OscInitTypeDef RCC_OscInitStruct = {0};
  RCC_ClkInitTypeDef RCC_ClkInitStruct = {0};

  /** Initializes the RCC Oscillators according to the specified parameters
  * in the RCC_OscInitTypeDef structure.
  */
  RCC_OscInitStruct.OscillatorType = RCC_OSCILLATORTYPE_HSI;
  RCC_OscInitStruct.HSIState = RCC_HSI_ON;
  RCC_OscInitStruct.HSICalibrationValue = RCC_HSICALIBRATION_DEFAULT;
  RCC_OscInitStruct.PLL.PLLState = RCC_PLL_NONE;
  if (HAL_RCC_OscConfig(&RCC_OscInitStruct) != HAL_OK)
  {
    Error_Handler();
  }

  /** Initializes the CPU, AHB and APB buses clocks
  */
  RCC_ClkInitStruct.ClockType = RCC_CLOCKTYPE_HCLK|RCC_CLOCKTYPE_SYSCLK
                              |RCC_CLOCKTYPE_PCLK1|RCC_CLOCKTYPE_PCLK2;
  RCC_ClkInitStruct.SYSCLKSource = RCC_SYSCLKSOURCE_HSI;
  RCC_ClkInitStruct.AHBCLKDivider = RCC_SYSCLK_DIV1;
  RCC_ClkInitStruct.APB1CLKDivider = RCC_HCLK_DIV1;
  RCC_ClkInitStruct.APB2CLKDivider = RCC_HCLK_DIV1;

  if (HAL_RCC_ClockConfig(&RCC_ClkInitStruct, FLASH_LATENCY_0) != HAL_OK)
  {
    Error_Handler();
  }
}

/**
  * @brief ADC1 Initialization Function
  * @param None
  * @retval None
  */
static void MX_ADC1_Init(void)
{
  ADC_ChannelConfTypeDef sConfig = {0};

  hadc1.Instance = ADC1;
  hadc1.Init.ScanConvMode = ADC_SCAN_DISABLE;
  hadc1.Init.ContinuousConvMode = DISABLE;
  hadc1.Init.DiscontinuousConvMode = DISABLE;
  hadc1.Init.ExternalTrigConv = ADC_SOFTWARE_START;
  hadc1.Init.DataAlign = ADC_DATAALIGN_RIGHT;
  hadc1.Init.NbrOfConversion = 1;
  if (HAL_ADC_Init(&hadc1) != HAL_OK)
  {
    Error_Handler();
  }

  /** Configure Regular Channel
  */
  sConfig.Channel = ADC_CHANNEL_0;
  sConfig.Rank = ADC_REGULAR_RANK_1;
  sConfig.SamplingTime = ADC_SAMPLETIME_1CYCLE_5;
  if (HAL_ADC_ConfigChannel(&hadc1, &sConfig) != HAL_OK)
  {
    Error_Handler();
  }
}

/**
  * @brief USART1 Initialization Function
  * @param None
  * @retval None
  */
static void MX_USART1_UART_Init(void)
{
  huart1.Instance = USART1;
  huart1.Init.BaudRate = 115200;
  huart1.Init.WordLength = UART_WORDLENGTH_8B;
  huart1.Init.StopBits = UART_STOPBITS_1;
  huart1.Init.Parity = UART_PARITY_NONE;
  huart1.Init.Mode = UART_MODE_TX_RX;
  huart1.Init.HwFlowCtl = UART_HWCONTROL_NONE;
  huart1.Init.OverSampling = UART_OVERSAMPLING_16;
  if (HAL_UART_Init(&huart1) != HAL_OK)
  {
    Error_Handler();
  }
}

/**
  * @brief USART2 Initialization Function
  * @param None
  * @retval None
  */
static void MX_USART2_UART_Init(void)
{
  huart2.Instance = USART2;
  huart2.Init.BaudRate = 9600;
  huart2.Init.WordLength = UART_WORDLENGTH_8B;
  huart2.Init.StopBits = UART_STOPBITS_1;
  huart2.Init.Parity = UART_PARITY_NONE;
  huart2.Init.Mode = UART_MODE_TX_RX;
  huart2.Init.HwFlowCtl = UART_HWCONTROL_NONE;
  huart2.Init.OverSampling = UART_OVERSAMPLING_16;
  if (HAL_UART_Init(&huart2) != HAL_OK)
  {
    Error_Handler();
  }
}

/**
  * @brief GPIO Initialization Function
  * @param None
  * @retval None
  */
static void MX_GPIO_Init(void)
{
  /* GPIO Ports Clock Enable */
  __HAL_RCC_GPIOD_CLK_ENABLE();
  __HAL_RCC_GPIOA_CLK_ENABLE();
}

/* USER CODE BEGIN 4 */
/**
  * @brief  Ham ngat UART - Nhan tung byte tu Gateway qua UART2 (LoRa)
  */
void HAL_UART_RxCpltCallback(UART_HandleTypeDef *huart)
{
    if (huart->Instance == USART2)
    {
        if (rx_byte != '\n' && rx_byte != '\r')
        {
            rx_buffer[rx_index++] = rx_byte;
            if (rx_index >= 20) rx_index = 0; // Chong tran bo nho
        }
        else if (rx_index > 0)
        {
            rx_buffer[rx_index] = '\0';  // Null-terminate
            cmd_ready = 1;               // Bao cho main biet
        }

        // Kich hoat lai ngat de lang nghe byte tiep theo
        HAL_UART_Receive_IT(&huart2, &rx_byte, 1);
    }
}
/* USER CODE END 4 */

/**
  * @brief  This function is executed in case of error occurrence.
  * @retval None
  */
void Error_Handler(void)
{
  __disable_irq();
  while (1)
  {
  }
}




