/* USER CODE BEGIN Header */
/**
  ******************************************************************************
  * @file           : main.c
  * @brief          : Node 2 - BH1750 Light Sensor - LoRa Gateway Protocol
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
#define BH1750_ADDRESS      (0x23 << 1)   // ADDR pin = LOW
#define BH1750_POWER_ON     0x01
#define BH1750_RESET        0x07
#define BH1750_CONT_HI_RES  0x10          // Che do do lien tuc, do phan giai cao (1 lux)
/* USER CODE END PTD */

/* Private define ------------------------------------------------------------*/
/* USER CODE BEGIN PD */
#define NODE_ID  2   // <-- Day la Node 2 (BH1750)
/* USER CODE END PD */

/* Private macro -------------------------------------------------------------*/
/* USER CODE BEGIN PM */

/* USER CODE END PM */

/* Private variables ---------------------------------------------------------*/
I2C_HandleTypeDef hi2c1;
UART_HandleTypeDef huart1;
UART_HandleTypeDef huart2;

/* USER CODE BEGIN PV */

/* USER CODE END PV */

/* Private function prototypes -----------------------------------------------*/
void SystemClock_Config(void);
static void MX_GPIO_Init(void);
static void MX_USART1_UART_Init(void);
static void MX_USART2_UART_Init(void);
static void MX_I2C1_Init(void);
/* USER CODE BEGIN PFP */

/* ---------- Debug print qua UART1 (Serial monitor may tinh) ---------- */
char buff[60];
void mPrint(const char* format, ...) {
    va_list args;
    va_start(args, format);
    vsnprintf(buff, sizeof(buff), format, args);
    va_end(args);
    HAL_UART_Transmit(&huart1, (uint8_t*)buff, strlen(buff), 1000);
}

/* ---------- BH1750 functions ---------- */
void BH1750_Init(void) {
    uint8_t cmd;
    cmd = BH1750_POWER_ON;
    HAL_I2C_Master_Transmit(&hi2c1, BH1750_ADDRESS, &cmd, 1, HAL_MAX_DELAY);
    HAL_Delay(10);
    cmd = BH1750_CONT_HI_RES;
    HAL_I2C_Master_Transmit(&hi2c1, BH1750_ADDRESS, &cmd, 1, HAL_MAX_DELAY);
    HAL_Delay(150);  // Cho lan do dau tien hoan thanh (~120ms)
}

float BH1750_ReadLight(void) {
    uint8_t buffer[2] = {0, 0};
    if (HAL_I2C_Master_Receive(&hi2c1, BH1750_ADDRESS, buffer, 2, 100) == HAL_OK) {
        uint16_t val = (buffer[0] << 8) | buffer[1];
        return (float)val / 1.2f;
    }
    return -1.0f;
}

/* USER CODE END PFP */

/* Private user code ---------------------------------------------------------*/
/* USER CODE BEGIN 0 */

/* ---------- Bien phuc vu nhan lenh tu Gateway qua UART2 (LoRa) ---------- */
uint8_t rx_byte;          // Nhan tung byte mot qua ngat
char    rx_buffer[20];    // Buffer rap chuoi lenh (VD: "GET_N2")
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
  MX_USART1_UART_Init();
  MX_USART2_UART_Init();
  MX_I2C1_Init();

  /* USER CODE BEGIN 2 */
  BH1750_Init();

  // Bat ngat UART2 de lang nghe lenh tu Gateway
  HAL_UART_Receive_IT(&huart2, &rx_byte, 1);
  mPrint("Node %d (BH1750) Ready. Listening for Gateway...\r\n", NODE_ID);
  /* USER CODE END 2 */

  /* Infinite loop */
  /* USER CODE BEGIN WHILE */
  while (1)
  {
      // Neu co lenh gui den tu Gateway
      if (cmd_ready == 1)
      {
          cmd_ready = 0; // Tat co de tranh xu ly lap lai

          // Tao chuoi lenh mong doi (Node 2 mong nhan "GET_N2")
          char expected_cmd[12];
          sprintf(expected_cmd, "GET_N%d", NODE_ID);

          // Kiem tra lenh co dung ten minh khong (dung strstr de an toan)
          if (strstr(rx_buffer, expected_cmd) != NULL)
          {
              mPrint("Gateway goi: %s. Dang doc cam bien...\r\n", rx_buffer);

              // Doc cam bien BH1750
              float lux = BH1750_ReadLight();

              // Neu doc loi, thu reset va doc lai 1 lan
              if (lux < 0) {
                  mPrint("Loi BH1750, dang reset I2C...\r\n");
                  HAL_I2C_DeInit(&hi2c1);
                  HAL_Delay(10);
                  MX_I2C1_Init();
                  BH1750_Init();
                  lux = BH1750_ReadLight();
              }

              // Dong goi du lieu va gui tra qua UART2 (LoRa)
              // Dinh dang: N2,<lux>\n
              // Vi STM32 co the tat float trong sprintf, ep kieu sang int
              int lux_i = (lux >= 0) ? (int)lux : -1;
              int lux_d = (lux >= 0) ? (int)((lux - lux_i) * 10) : 0;

              if (lux >= 0) {
                  sprintf(lora_tx_buffer, "N%d,%d.%d\n", NODE_ID, lux_i, lux_d);
              } else {
                  sprintf(lora_tx_buffer, "N%d,-1\n", NODE_ID);
              }

              HAL_UART_Transmit(&huart2, (uint8_t*)lora_tx_buffer, strlen(lora_tx_buffer), 1000);
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
      // Viec nhan LoRa da duoc ngat xu ly ngam
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

  RCC_OscInitStruct.OscillatorType = RCC_OSCILLATORTYPE_HSI;
  RCC_OscInitStruct.HSIState = RCC_HSI_ON;
  RCC_OscInitStruct.HSICalibrationValue = RCC_HSICALIBRATION_DEFAULT;
  RCC_OscInitStruct.PLL.PLLState = RCC_PLL_NONE;
  if (HAL_RCC_OscConfig(&RCC_OscInitStruct) != HAL_OK)
  {
    Error_Handler();
  }

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
  * @brief I2C1 Initialization Function
  */
static void MX_I2C1_Init(void)
{
  hi2c1.Instance = I2C1;
  hi2c1.Init.ClockSpeed = 100000;
  hi2c1.Init.DutyCycle = I2C_DUTYCYCLE_2;
  hi2c1.Init.OwnAddress1 = 0;
  hi2c1.Init.AddressingMode = I2C_ADDRESSINGMODE_7BIT;
  hi2c1.Init.DualAddressMode = I2C_DUALADDRESS_DISABLE;
  hi2c1.Init.OwnAddress2 = 0;
  hi2c1.Init.GeneralCallMode = I2C_GENERALCALL_DISABLE;
  hi2c1.Init.NoStretchMode = I2C_NOSTRETCH_DISABLE;
  if (HAL_I2C_Init(&hi2c1) != HAL_OK)
  {
    Error_Handler();
  }
}

/**
  * @brief USART1 Initialization Function (Debug - 115200 baud)
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
  * @brief USART2 Initialization Function (LoRa - 9600 baud)
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
  */
static void MX_GPIO_Init(void)
{
  __HAL_RCC_GPIOD_CLK_ENABLE();
  __HAL_RCC_GPIOA_CLK_ENABLE();
  __HAL_RCC_GPIOB_CLK_ENABLE();
}

/* USER CODE BEGIN 4 */

/**
  * @brief  Ham ngat UART - Nhan tung byte tu Gateway qua UART2 (LoRa)
  *         Khi nhan xong ki tu '\n', dat co cmd_ready = 1 de main xu ly
  */
void HAL_UART_RxCpltCallback(UART_HandleTypeDef *huart)
{
    if (huart->Instance == USART2)
    {
        if (rx_byte != '\n' && rx_byte != '\r')
        {
            // Luu ki tu vao buffer
            rx_buffer[rx_index++] = rx_byte;
            if (rx_index >= 20) rx_index = 0; // Chong tran bo nho
        }
        else if (rx_index > 0)
        {
            // Nhan xong 1 lenh hoan chinh
            rx_buffer[rx_index] = '\0';  // Null-terminate
            cmd_ready = 1;               // Bao cho main biet
        }

        // Kich hoat lai ngat de tiep tuc lang nghe byte tiep theo
        HAL_UART_Receive_IT(&huart2, &rx_byte, 1);
    }
}

/* USER CODE END 4 */

/**
  * @brief  This function is executed in case of error occurrence.
  */
void Error_Handler(void)
{
  __disable_irq();
  while (1)
  {
  }
}
