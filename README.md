# UART 통신 기반 센서 2종 및 시계·스톱워치 통합 제어 시스템

Basys 3 (Artix-7) FPGA에서 동작하는 다기능 디지털 시스템입니다. 보드 버튼이나 PC의 UART ASCII 명령으로 **시계 · 스톱워치 · 초음파 거리 센서(HC-SR04) · 온습도 센서(DHT11)** 4가지 모드를 제어하고, 결과를 4자리 FND와 UART로 출력합니다.

```
PC · 버튼 ─► UART RX ─► cmd_control ─► datapath ─► mux_4x1 ─► FND · UART TX
```

**5조** · 조수영, 박경훈, 오창민, 박재균 · 2026.11.02

---

## 목차

1. [주요 기능](#주요-기능)
2. [개발 환경](#개발-환경)
3. [팀 구성](#팀-구성)
4. [파일 구성](#파일-구성)
5. [시스템 구조](#시스템-구조)
6. [입출력 포트](#입출력-포트)
7. [모드별 사용법](#모드별-사용법)
8. [UART 명령과 응답](#uart-명령과-응답)
9. [모듈 상세](#모듈-상세)
10. [검증](#검증)
11. [Implementation 결과](#implementation-결과)
12. [빌드 및 실행](#빌드-및-실행)
13. [결론 및 개선 방향](#결론-및-개선-방향)
14. [참고 사항](#참고-사항)

---

## 주요 기능

- 버튼(R·L·U·D)과 UART 명령(R·L·U·D) **둘 다**로 시계, 스톱워치, 센서 2종을 제어할 수 있습니다. 두 입력이 같은 클럭에 들어오면 하나의 입력으로 처리합니다.
- `S` 명령을 보내면 **현재 모드의 값**(시각, 거리, 온습도)을 UART로 돌려줍니다.
- 명령을 처리한 결과를 회신합니다. 성공하면 `DONE`, 센서 측정 중에 측정 명령이 오면 `FAIL`, 지원하지 않는 명령이면 `NONE`을 보냅니다.
- SR04는 58 µs = 1 cm로 거리를 계산합니다.
- DHT11은 각 단계에 100 µs 타임아웃을 두고, 체크섬이 맞을 때만 값을 갱신합니다.

| 동작 모드 `{sw1, sw0}` | 기능 |
|---|---|
| `00` | 시계 (시:분:초:1/100초, 시간 수정 가능) |
| `01` | 스톱워치 (업/다운 카운트, 랩타임) |
| `10` | 초음파 거리 센서 HC-SR04 (cm) |
| `11` | 온습도 센서 DHT11 |

---

## 개발 환경

| 항목 | 내용 |
|---|---|
| 보드 | Digilent Basys 3 (Xilinx Artix-7, 100 MHz) |
| 센서 | HC-SR04 (초음파 거리), DHT11 (온습도) |
| 입력 | 버튼 4개, 스위치 4개 |
| 언어 · 툴 | Verilog HDL, Xilinx Vivado |
| 시리얼 터미널 | ComportMaster (9600 bps, 8N1) |

---

## 팀 구성

| 이름 | 역할 |
|---|---|
| 조수영 | `ascii_sender`, `ascii_decoder` 설계 및 검증, 스위치에 따른 FND 표시 모드 검증 |
| 박경훈 | Control Unit 설계, Top Module 검증용 testbench 작성 |
| 오창민 | Top Integration, FPGA Implementation & Verification |
| 박재균 | HC-SR04 설계 및 검증, DHT11 설계 및 검증 |

---

## 파일 구성

| 파일 | 내용 | 모듈 |
|---|---|---|
| `top.v` | 최상위, 데이터패스, 모드 선택 MUX, 버튼 디바운서 | `uart_fifo_ascii`, `datapath`, `mux_4x1`, `btn_debounce` |
| `uart.v` | UART 송수신 + FIFO | `uart`, `uart_rx`, `uart_tx`, `baud_tick_gen`, `fifo`, `control_unit`, `register_file` |
| `cmd.v` | UART 명령 해석과 응답 생성 | `cmd_control_unit`, `ascii_decoder`, `ascii_sender` |
| `watch_stopwatch.v` | 시계, 스톱워치 | `stopwatch_*`, `tick_counter`, `tick_gen_100hz`, `mux_2x1x4_lapstop`, `watch_*`, `tick_counter_watch`, `tick_gen_100hz_watch` |
| `sensor.v` | SR04, DHT11 제어 | `sr04_top`, `sr04_control`, `dht11_top`, `dht11_control`, `us_tick_gen` |
| `fnd.v` | 4자리 7-세그먼트 표시 | `fnd_controller`, `clk_div_2000Hz`, `counter_8`, `decoder_2x4`, `mux_2x1`, `mux_8x1`, `digit_splitter`, `dot_comparator`, `flash_digit`, `bcd` |

**최상위 모듈: `uart_fifo_ascii`** (`top.v`)

---

## 시스템 구조

### 모듈 계층

```
uart_fifo_ascii
├── btn_debounce ×4             (btnR / btnL / btnD / btnU)
├── uart
│   ├── baud_tick_gen           (9600 bps × 16 오버샘플링)
│   ├── uart_rx ── fifo (RX)
│   └── uart_tx ── fifo (TX)    fifo = control_unit + register_file
├── cmd_control_unit
│   ├── ascii_decoder           (수신 문자 → 명령 펄스)
│   └── ascii_sender            (결과 · 값 → ASCII 바이트)
├── datapath
│   ├── stopwatch_top ── stopwatch_control_unit, stopwatch_datapath
│   ├── watch_top     ── watch_control_unit, watch_datapath
│   ├── sr04_top      ── us_tick_gen, sr04_control
│   └── dht11_top     ── us_tick_gen, dht11_control
├── mux_4x1                     (모드별 32비트 데이터 선택)
└── fnd_controller
```

### 데이터 흐름

```
버튼 ─► 디바운서 ──┐ (OR)
                   ├─► cmd_control_unit ─► 모드 분배(sw1·sw0) ─► datapath ─► mux_4x1 ─┬─► fnd_controller ─► FND
UART RX ─► FIFO ───┘          │                     ▲ busy                           │
                              │                     └──── sr04_busy · dht11_busy      │
                              └─► ascii_sender ◄───── display_data[31:0] ◄────────────┘
                                       │
                                       └─► TX FIFO ─► UART TX
```

### 모드별 32비트 데이터 형식 (`mux_4x1` 입력)

| 모드 | `[31:24]` | `[23:16]` | `[15:8]` | `[7:0]` |
|---|---|---|---|---|
| 시계 / 스톱워치 | 시 | 분 | 초 | 1/100초 |
| SR04 | 0 | 0 | 거리 백의 자리 (0–4) | 거리 0–99 |
| DHT11 | 습도 정수 | 습도 소수 | 온도 정수 | 온도 소수 |

---

## 입출력 포트

`uart_fifo_ascii` 기준입니다.

| 포트 | 방향 | 설명 |
|---|---|---|
| `clk` | in | 100 MHz 시스템 클럭 |
| `rst` | in | 비동기 리셋 (High) |
| `rx` / `tx` | in / out | UART (9600 bps, 8N1), Basys 3 USB-UART |
| `sw0`, `sw1` | in | 모드 선택 |
| `sw2` | in | FND 상/하위 표시 전환 |
| `sw3` | in | 시계 시간 수정 모드 |
| `btnR`, `btnL`, `btnU`, `btnD` | in | 조작 버튼 (디바운스 후 상승 에지 1펄스) |
| `sr04_trigger` / `sr04_echo` | out / in | HC-SR04 TRIG / ECHO |
| `dht11_io` | inout | DHT11 DATA (오픈 드레인, 풀업 필요) |
| `fnd_com[3:0]` | out | FND 자리 선택 `{com3, com2, com1, com0}` (Active Low) |
| `fnd_font[7:0]` | out | FND 세그먼트 `{dp, g, f, e, d, c, b, a}` (Active Low) |

---

## 모드별 사용법

### FND 표시 전환

| 스위치 | 동작 |
|---|---|
| `{sw1, sw0}` | `00` 시계 · `01` 스톱워치 · `10` SR04 거리 · `11` DHT11 온습도 |
| `sw2` | `0`: 초 : 1/100초 / 온도 · `1`: 시 : 분 / 습도 |
| `sw3` | 시계 모드에서 `0`: 일반 · `1`: 시간 수정 모드 |

### 1. 시계 (`00`)

리셋하면 `12:00:00:00`부터 시작합니다.

시간 수정 모드(`sw3 = 1`)에서는 시계가 멈추고, 선택한 자리가 2 Hz로 깜빡입니다.

| 버튼 / 명령 | 동작 |
|---|---|
| `L` | 수정할 자리를 왼쪽으로 이동 (1의 자리 → 10 → 100 → 1000 → 1의 자리…) |
| `R` | 수정할 자리를 오른쪽으로 이동 |
| `U` | 선택한 자리 값 +1 |
| `D` | 선택한 자리 값 −1 |

- 오른쪽 두 자리는 하위 값(`sw2 = 0`이면 1/100초, `1`이면 분)을 수정하고, 왼쪽 두 자리는 상위 값(초 또는 시)을 수정합니다.
- 값이 최댓값을 넘지 않도록 자리별로 순환합니다. 시는 00–23, 분과 초는 00–59입니다.
- 가운데 점(DP)은 1/100초 값에 따라 0.5초 간격으로 깜빡입니다.

### 2. 스톱워치 (`01`)

| 버튼 / 명령 | 상태 | 동작 |
|---|---|---|
| `R` | 정지 / 동작 / 랩 | RUN ↔ STOP |
| `L` | 정지 | 0으로 초기화 (랩 기록도 삭제) |
| `U` | 정지 | 업 카운트 ↔ 다운 카운트 전환 |
| `D` | 동작 | 현재 시간을 랩으로 저장하고 랩 화면으로 전환 (랩 화면에서 다시 누르면 새로 저장) |

랩 화면에서도 내부 카운트는 계속 진행됩니다. `R`을 누르면 정지하면서 현재 시간 화면으로 돌아옵니다.

### 3. 초음파 거리 센서 HC-SR04 (`10`)

- `R`(버튼 또는 UART)로 측정을 시작합니다. 측정 중(busy)에 들어온 요청은 무시합니다.
- FND에 거리를 4자리 cm 값으로 표시합니다 (예: `0123`).

### 4. 온습도 센서 DHT11 (`11`)

- `R`(버튼 또는 UART)로 측정을 시작합니다. 측정 중에 들어온 요청은 무시합니다.
- FND: `sw2 = 0`이면 온도 정수.소수, `sw2 = 1`이면 습도 정수.소수를 표시합니다.
- DHT11 데이터시트는 측정 간격을 최소 1초로 권장합니다.

---

## UART 명령과 응답

**통신 설정:** 9600 bps, 데이터 8비트, 패리티 없음, 정지 비트 1 (8N1)

### 명령어 (대소문자 구분 없음)

| 명령 | 의미 |
|---|---|
| `R` `r` | 버튼 R과 같음 |
| `L` `l` | 버튼 L과 같음 |
| `U` `u` | 버튼 U와 같음 |
| `D` `d` | 버튼 D와 같음 |
| `S` `s` | 현재 모드의 값 요청 |

### 모드별 명령 처리

| 모드 | 처리 | 응답 |
|---|---|---|
| `00` 시계 | R·L·U·D → watch 버튼 | `DONE`, 그 외 문자 → `NONE` |
| `01` 스톱워치 | R·L·U·D → stopwatch 버튼 | `DONE`, 그 외 문자 → `NONE` |
| `10` SR04 | R → `sr04_start` | busy면 `FAIL`, L·U·D·그 외 → `NONE` |
| `11` DHT11 | R → `dht11_start` | busy면 `FAIL`, L·U·D·그 외 → `NONE` |

`S`는 모든 모드에서 현재 값을 보냅니다.

### 응답 형식

모든 응답은 공백(SP) 하나로 끝나며, 줄바꿈(CR/LF)은 보내지 않습니다.

| 종류 | 형식 | 예시 |
|---|---|---|
| 시계 / 스톱워치 | `HH:MM:SS:CC␠` | `12:45:13:89 ` |
| SR04 | 앞자리 0을 생략한 거리 + `cm␠` | `289cm ` / `3cm ` |
| DHT11 | 습도 `%` 온도 `*C␠` (정수만) | `24%43*C ` |
| 성공 | `DONE␠` | |
| 실패 (busy) | `FAIL␠` | |
| 미지원 명령 | `NONE␠` | |

`ascii_sender`의 이벤트 우선순위: `status(S)` > `success` > `fail` > `cmdNONE`

---

## 모듈 상세

### UART (`uart.v`)

- **프레임:** Idle(1) → Start(0) → Data 8비트(LSB부터) → Stop(1), 1프레임 = 10비트
- **Baud time:** 1 / 9600 ≈ 104.16 µs, 최대 약 960 byte/s
- **16배 오버샘플링:** `b_tick` = 100 MHz ÷ (9600 × 16) ≈ 651 클럭마다 1틱
- **RX FSM** (`IDLE → START → DATA → STOP`): Start 비트를 감지하면 8틱(½ 비트)을 기다려 비트 중앙에 맞춥니다. 그 뒤 16틱마다 샘플링하고 `data ← {rx, data[7:1]}`로 오른쪽 시프트합니다. STOP 상태가 끝나면 `rx_done`을 1클럭 펄스로 냅니다.
- **TX FSM** (`IDLE → START → DATA → STOP`): `tx_start`를 받으면 바로 START로 갑니다. 첫 `b_tick`에 `tx = 0`을 내보내고, 이후 16틱마다 `data[0]`을 출력하며 오른쪽으로 시프트합니다. STOP 상태가 끝나면 `tx_busy = 0`이 됩니다.
- **FIFO:** 깊이 4 × 8비트 원형 버퍼입니다.
  - 쓰기는 클럭에 동기되고(`we = ~full & push`), 읽기는 조합 출력입니다(`pop_data = mem[rptr]`).
  - push한 뒤 `wptr + 1 == rptr`이면 full, pop한 뒤 `rptr + 1 == wptr`이면 empty가 됩니다.
  - push와 pop이 동시에 오면 full이나 empty 상태에 따라 한쪽만 처리하거나 둘 다 처리합니다.

### cmd_control_unit (`cmd.v`)

PC에서 온 ASCII 명령과 보드 버튼 명령을 OR로 합칩니다. 그다음 `{sw1, sw0}`로 선택된 모듈에만 전달하고, 처리 결과를 TX로 회신하는 중앙 제어 블록입니다.

- **ascii_decoder:** RX FIFO가 비어 있지 않으면 같은 클럭에 pop하고, 문자에 따라 `cmdR / cmdL / cmdD / cmdU / status / cmdNONE` 중 하나를 1클럭 펄스로 냅니다.
- **ascii_sender:** `IDLE`과 `SEND` 두 상태로 동작합니다.
  - `IDLE`에서 이벤트가 오면 32비트 `send_data`를 저장하고 `SEND`로 갑니다.
  - `SEND`에서는 1클럭에 1바이트씩 TX FIFO에 push합니다. TX FIFO가 full이면 다음 바이트를 기다렸다가 이어서 보냅니다.

### HC-SR04 (`sensor.v`)

| 항목 | 데이터시트 사양 |
|---|---|
| 측정 범위 | 2–400 cm |
| 정확도 | ±3 mm |
| 초음파 / 유효각 | 40 kHz / 15° |
| 거리 환산 | ECHO HIGH(µs) ÷ 58 ≈ 거리(cm) |
| 측정 주기 | 60 ms 초과 권장 |

| 핀 | 역할 |
|---|---|
| VCC | 전원 |
| TRIG | FPGA → 센서: 10 µs 시작 펄스 |
| ECHO | 센서 → FPGA: 왕복 시간 펄스 |
| GND | 공통 접지 |

`sr04_control` FSM (1 tick = 1 µs):

| 상태 | 동작 |
|---|---|
| `IDLE` | start를 받으면 TRIG를 High로 올리고 START로 이동 |
| `START` | TRIG High를 10 µs 유지한 뒤 WAIT로 이동 |
| `WAIT` | ECHO 상승을 기다림. 상승하면 거리 카운터를 초기화하고 DISTANCE로 이동 |
| `DISTANCE` | ECHO High 동안 58 µs마다 1 cm 증가 (29부터 세서 반올림). ECHO가 하강하거나 400 cm에 도달하면 거리를 저장하고 STOP으로 이동 |
| `STOP` | 10 ms 대기한 뒤 `done`을 1클럭 펄스로 내고 IDLE로 복귀 |

`busy`는 IDLE이 아닌 모든 상태에서 1이고, ECHO 입력은 2단 플립플롭으로 동기화합니다.

### DHT11 (`sensor.v`)

| 항목 | 온도 | 상대습도 |
|---|---|---|
| 측정 범위 | 0–50 °C | 20–90 %RH |
| 정확도 | ±2 °C | ±5 %RH |
| 분해능 | 1 °C | 1 %RH |
| 측정 간격 | 최소 1초 | 최소 1초 |

데이터 40비트의 구성은 습도 정수 8, 습도 소수 8, 온도 정수 8, 온도 소수 8, 체크섬 8비트입니다. MSB부터 수신합니다.

비트 판정 기준은 다음과 같습니다.
- 데이터시트상 비트 0은 HIGH 26–28 µs, 비트 1은 HIGH 약 70 µs입니다.
- 구현에서는 HIGH 폭이 40 µs 이상이면 1, 미만이면 0으로 판정합니다.
- 체크섬은 앞 4바이트 합의 하위 8비트와 비교합니다.

`dht11_control` FSM (1 tick = 1 µs):

| 상태 | 동작 |
|---|---|
| `IDLE` | 데이터 선을 해제(Z). start를 받으면 데이터와 카운터를 초기화하고 START로 이동 |
| `START` | 데이터 선을 20 ms 동안 Low로 구동 (데이터시트 기준 18 ms 이상) |
| `WAIT` | 선을 해제하고 센서의 응답 Low를 기다림 |
| `SYNC_LOW` / `SYNC_HIGH` | 센서 응답(Low 80 µs → High 80 µs) 확인 |
| `DATA_SYNC` | 비트 시작 Low 구간. 상승하면 BIT_COUNT로 이동 |
| `BIT_COUNT` | HIGH 폭을 셈. 하강 시 비트를 저장하고, 40비트를 다 받으면 체크섬을 검사 |
| `STOP` | 60 µs 대기한 뒤 `done`을 내고 IDLE로 복귀 |

- 응답 대기 단계(WAIT ~ BIT_COUNT)는 각각 100 µs 타임아웃이 있습니다. 타임아웃이 나면 STOP으로 가고 `valid = 0`이 됩니다.
- 체크섬이 맞을 때만 습도와 온도 값을 갱신하고 `valid = 1`이 됩니다.

### FND (`fnd.v`)

- `fnd_font[7:0] = {dp, g, f, e, d, c, b, a}`, `fnd_com[3:0] = {com3, com2, com1, com0}`이며, 둘 다 0일 때 켜집니다(Active Low).
- 한 번에 한 자리만 켜고 2 kHz로 빠르게 돌아가며 켜서, 잔상으로 4자리가 모두 보이게 합니다.
- 처리 순서는 `mux_2x1`(sw2로 상·하위 선택) → `digit_splitter`(÷10, %10) → `mux_8x1`(자리 선택) → `bcd`(숫자 → 세그먼트 패턴)입니다.
- `dot_comparator`는 `value0 ≥ 50`이면 DP를 끕니다. `flash_digit`은 수정 중인 자리를 2 Hz로 깜빡이게 합니다.

---

## 검증

Vivado 시뮬레이터로 모듈 단위와 Top 통합 시뮬레이션을 했습니다. 공통 조건은 다음과 같습니다.

- 클럭 100 MHz (`#5` 토글)
- UART 9600 bps 8N1, 1비트 = 104,160 ns (651 × 16 tick × 10 ns)

> 테스트벤치 파일은 이 저장소에 포함되어 있지 않습니다.

### Top Module Testbench 구성

```
RX Driver ──rx──►            ──tx──► TX Monitor ──실제값──┐
SR04 Model ◄─trigger/echo─►   DUT                        ▼
DHT11 Model ◄──dht11_io──►    │ 스냅샷 ─► Golden Model ─기대값─► Scoreboard
```

### 시뮬레이션 시나리오

| 구분 | 목적 | 주요 입력 | 확인 결과 |
|---|---|---|---|
| **S1** | HC-SR04 측정 FSM 검증 | start 펄스 (busy 중 재입력 포함), ECHO HIGH 600 µs / 1,200 µs | TRIG 10 µs 출력, 거리 10 cm · 20 cm 저장, done 1클럭, busy 중 재입력 무시, 10 ms 후 busy = 0 |
| **S2** | DHT11 수신 FSM 검증 | start 펄스 (busy = 0 / 1), 데이터 HIGH 30 µs(0) · 70 µs(1) | busy 중 START 유지, HIGH 폭 1 µs 단위 계수, tick < 40이면 비트 0 저장, 비트 수 증가 |
| **S3** | `ascii_sender` 응답 생성 검증 | fail · success · cmdNONE · status 펄스, 모드별 send_data, 전송 중 full = 1 (30 ns) | `FAIL ` `DONE ` `NONE `, `24%43*C `, `289cm `, `3cm `(0 생략), `12:45:13:89 `, full 동안 대기 후 누락 · 중복 없이 이어서 전송 |
| **S4** | UART `s` 명령 Top 통합 검증 | sw = 10, echo 123 cm 측정 후 rx `s` | `rx_pop` · `w_status` 1클럭, `123cm ` 6바이트가 TX FIFO(깊이 4)를 넘어도 full 처리 정상, Scoreboard **PASS: 6 bytes checked, 0 error** |
| **S5** | 명령 → 버튼 신호 분배 검증 | sw = 01, rx `r` | `stopwatch_btnR`만 1 tick, 나머지 제어 출력 0, STOP → RUN 1회 전환, `DONE ` |
| **S6** | 명령 · 버튼 동시 입력 검증 | sw = 01, rx `r` + btnR 같은 클럭 | OR로 합쳐 `stopwatch_btnR` 1 tick, RUN → STOP 1회만 전환, `DONE ` |

### 기능 검증 체크리스트

| 항목 | 조건 | 결과 |
|---|---|---|
| 시계 수정 r / l / u / d | sw = 00, sw3 = 1 | r · l: 수정 자리 이동, u · d: 선택 자리 +1 / −1 |
| 스톱워치 r / l / u / d | sw = 01 | r: RUN ↔ STOP, l: 초기화, u: up / down 전환, d: 랩타임 |
| 표시 모드 전환 | `{sw1, sw0}` = 00 – 11 | 시계 / 스톱워치 / SR04 / DHT11 순서로 FND 표시 |
| 표시 자리 전환 | sw2 = 0 / 1 (시계, 스톱워치) | 0: 초 : 1/100초, 1: 시 : 분 |
| busy 중 버튼 무시 | sw = 10 / 11, busy = 1, btnR | start 발생 안 함, 측정 유지 |

### 보드 동작 확인

- **버튼 제어:** SR04 모드(sw = 10)와 DHT11 모드(sw = 11)에서 R 버튼으로 거리, 습도, 온도 측정이 정상 동작함을 확인했습니다.
- **UART 제어 (ComportMaster):** 각 모드에서 `r`로 측정하고 `s`로 값을 받아, 거리와 습도·온도 출력이 정상임을 확인했습니다.

---

## Implementation 결과

| 항목 | 값 | 계산 |
|---|---|---|
| WNS (Worst Negative Slack) | **2.157 ns** | Required 15.216 ns − Arrival 13.058 ns |
| WHS (Worst Hold Slack) | **0.037 ns** | Arrival 1.721 ns − Required 1.684 ns |

WNS와 WHS가 모두 양수여서 Timing Violation이 없습니다.

---

## 빌드 및 실행

1. Vivado에서 Basys 3(`xc7a35tcpg236-1`)용 프로젝트를 만들고 `.v` 파일 6개를 Design Sources에 추가합니다.
2. `uart_fifo_ascii`를 Top 모듈로 지정합니다.
3. XDC 파일을 추가합니다. 클럭, 스위치 4개, 버튼 4개와 리셋, FND, USB-UART, 그리고 SR04와 DHT11을 연결할 Pmod 핀을 지정해야 합니다.
4. Synthesis → Implementation → Generate Bitstream 후 보드에 다운로드합니다.
5. ComportMaster 같은 시리얼 터미널을 9600 bps, 8N1로 연결하고 `r`, `s` 등의 명령을 보냅니다.

> XDC 제약 파일은 이 저장소에 포함되어 있지 않습니다.

---

## 결론 및 개선 방향

### 결론

1. **Multi-System Integration 완료:** FIFO-UART 인터페이스 기반의 ASCII 인코딩/디코딩 방식으로 시계, 스톱워치, SR04, DHT11을 하나의 시스템으로 통합했습니다.
2. **Sensor & ASCII Decoder / Sender FSM 설계:** UART로 받은 ASCII 데이터를 해석해 데이터패스를 제어하고, 결과를 PC로 안정적으로 보내는 구조를 구현했습니다.
3. **시뮬레이션과 FPGA 검증:** 6가지 시뮬레이션 시나리오로 엣지 케이스와 타이밍을 검증했고, 실제 보드 테스트로 최종 하드웨어 동작을 확인했습니다.

### 개선 방향

1. **실시간 처리 시스템으로 개선:** 지금은 SR04와 DHT11이 수동 start 입력이 있어야 측정합니다. 타이머로 자동 측정하고 데이터를 연속으로 처리하는 구조로 바꿀 예정입니다.
2. **Pipelining으로 타이밍 마진 확보:** SR04의 거리 계산 로직(1 µs 틱 분주, 100 cm / 1 cm 단위 연산) 사이에 CALC 단계와 파이프라인 레지스터를 넣어 크리티컬 패스를 줄일 계획입니다.
3. **고차원 연산으로 확장:** 지금은 단순한 ASCII 입출력 제어 수준입니다. ALU와 명령어 디코더를 통합해 사칙연산과 여러 명령어를 처리하는 프로세서 구조로 확장할 계획입니다.

---

## 참고 사항

- `top.v`의 `cmd_control_unit` 연결부 주석에는 `00 ST, 01 WT`라고 적혀 있지만, 실제 동작은 `00` = 시계, `01` = 스톱워치입니다 (`mux_4x1` 기준).
- `ascii_sender`가 응답을 보내는 동안 새로 들어온 명령은 동작은 하지만 그 명령의 응답은 보내지 않습니다.
- UART 응답에 줄바꿈이 없어서 터미널에서는 응답이 한 줄로 이어 붙어 보입니다.