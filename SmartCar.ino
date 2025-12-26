#include <Servo.h>

// ================= PINS =================
#define motor_1_f 7
#define motor_1_b 8
#define motor_2_f 2
#define motor_2_b 4
#define motor_1_speed 3
#define motor_2_speed 11

#define front_echo_pin 6
#define front_trig_pin 9

#define left_echo_pin A1
#define left_trig_pin A0

#define right_echo_pin 13
#define right_trig_pin 12

#define back_echo_pin A3
#define back_trig_pin A4

#define volt_level A2

#define buzzer_pin 10


// bool teach_session_started = false;



Servo servo_1;
int servo_pin = 5;


// ================= GLOBALS =================
byte speed_val = 255; 
char direction = 'S';

unsigned long last_reading = 0;

unsigned long buzzer_timer = 0;
bool buzzer_state = false;


enum robot_mode { idle, mode_manual, mode_auto, mode_parking, mode_teach, mode_repeat };
robot_mode current_mode = idle;

bool manual_buzzer_on = false;


// ================= TIMERS & STATE VARS =================
unsigned long state_timer = 0; 

// Data for voltage reading
unsigned long last_volt_read = 0;

// Data for teach/repeat
struct Step {
  char move;       
  byte speed;      
  unsigned long duration; 
};

#define MAX_STEPS 100
Step steps[MAX_STEPS];
int step_count = 0;

char last_move = 'S';
int last_speed = 0;
unsigned long move_start_time = 0;

int repeat_index = 0;
unsigned long repeat_start_time = 0;
bool repeating = false;
bool teach_recording = true;


// ================= AUTO MODE VARIABLES =================
// These states match your original avoid_obstacle steps exactly
enum AutoState { 
  A_IDLE,           // Not avoiding anything
  A_STOP_1,         // Initial stop (500ms)
  A_BACKWARD,       // Move back (200ms)
  A_STOP_2,         // Stop again (500ms)
  A_LOOK_LEFT,      // Servo 150 (500ms)
  A_LOOK_RIGHT,     // Servo 30 (500ms)
  A_CENTER_SERVO,   // Servo 90 (500ms)
  A_TURN,           // Turn Left/Right (200ms)
  A_STOP_FINAL      // Final Stop (200ms)
};
AutoState auto_state = A_IDLE; // Start in IDLE (Driving mode)

int obs_left_dist = 0;
int obs_right_dist = 0;

// ================= PARKING STATE MACHINE =================
enum ParkingState {
  S_SEARCHING, S_GAP_TIMER, S_ALIGN_LEFT, S_WAIT_1, 
  S_REVERSE_IN, S_WAIT_2, S_STRAIGHTEN, S_WAIT_3, 
  S_FINAL_FORWARD, S_DONE
};
ParkingState p_state = S_SEARCHING;

enum ParkSide { SIDE_NONE, SIDE_RIGHT, SIDE_LEFT };
ParkSide park_side = SIDE_NONE;
unsigned long gapStart = 0;
int prevRight = 0;
int prevLeft = 0;

// -------------------------------------------------------------
//  ------------------------- Setup ----------------------------
// -------------------------------------------------------------
void setup() {
  pinMode(motor_1_f, OUTPUT); pinMode(motor_1_b, OUTPUT);
  pinMode(motor_2_f, OUTPUT); pinMode(motor_2_b, OUTPUT);
  pinMode(motor_1_speed, OUTPUT); pinMode(motor_2_speed, OUTPUT);
  
  pinMode(front_echo_pin, INPUT); pinMode(front_trig_pin, OUTPUT);
  pinMode(left_echo_pin, INPUT); pinMode(left_trig_pin, OUTPUT);
  pinMode(right_echo_pin, INPUT); pinMode(right_trig_pin, OUTPUT);
  pinMode(back_echo_pin, INPUT); pinMode(back_trig_pin, OUTPUT);
  
  pinMode(volt_level, INPUT);
  last_reading = millis();
  
  pinMode(buzzer_pin, OUTPUT);
  digitalWrite(buzzer_pin, LOW);

  
  servo_1.attach(servo_pin);
  servo_1.write(90);
  
  Serial.begin(9600);
//  lastCommandTime = millis();
}

// -------------------------------------------------------------
//  ----------------------------- Loop -------------------------
// -------------------------------------------------------------
void loop() {
  bluetooth_read();

  // State Machine Switch
  switch (current_mode) {
    case idle:
      stop();
      break;
    case mode_manual:
      manual_mode();
      break;
    case mode_auto:
      auto_mode_non_blocking();
      break;
    case mode_parking:
      parking_mode_non_blocking();
      break;
    case mode_teach:
      teach_mode();
      break;
    case mode_repeat:
      repeat_mode();
      break;
  }

  volt_read();
}

// -------------------------------------------------------------
//  ------------------- Helper Functions -----------------------
// -------------------------------------------------------------

void reset_pwm() {
  analogWrite(motor_1_speed, 0);
  analogWrite(motor_2_speed, 0);
}


bool check_timer(unsigned long duration) {
  if (millis() - state_timer >= duration) {
    return true;
  }
  return false;
}

void reset_timer() {
  state_timer = millis();
}

void bluetooth_read() {
  while (Serial.available()) {
    char c = Serial.read();
//    Serial.print(c);
//    Serial.println(current_mode);
//    lastCommandTime = millis();
    handleCommand(c);
  }
}

void handleCommand(char cmd) {
  
  if (cmd == 'Q') {
    stop();                     // stop motors
    noTone(buzzer_pin);          // stop buzzer
    buzzer_state = false;

    direction = 'S';             // stop manual movement
    auto_state = A_IDLE;         // cancel auto avoid
    p_state = S_SEARCHING;       // reset parking state
    repeating = false;           // stop repeat mode

    current_mode = idle;         // go to safe idle mode
    return;
  }
  
  noTone(buzzer_pin);     
  buzzer_state = false;
  
  if (cmd == 'M') { noTone(buzzer_pin); current_mode = mode_manual; reset_pwm(); direction = 'S'; stop(); return; }
  
  if (cmd == 'A') { 
    current_mode = mode_auto; 
    auto_state = A_IDLE; // Reset to driving
    servo_1.write(90); 
    stop(); 
    return; 
  }
  
  if (cmd == 'P') {                 // Park RIGHT
    current_mode = mode_parking;
    p_state = S_SEARCHING;
    park_side = SIDE_RIGHT;
    stop();
    return;
  }

  if (cmd == 'p') {                 // Park LEFT
    current_mode = mode_parking;
    p_state = S_SEARCHING;
    park_side = SIDE_LEFT;
    stop();
    return;
  }

  
  if (cmd == 'T') { 
    current_mode = mode_teach; 
    for (int i = 0; i < MAX_STEPS; i++) {
    steps[i].move = 'S';
    steps[i].speed = 0;
    steps[i].duration = 0;
  }
    step_count = 0; 
    last_move = 'S'; 
    last_speed = speed_val; 
    move_start_time = millis(); 
    teach_recording = true; 
    stop(); 
    return; 
  }
  
  if (cmd == 'R') { 
    current_mode = mode_repeat; 
    repeating = false; 
    stop(); 
    return; 
  }
  
  if (cmd == 'Z') {
    manual_buzzer_on = true;
    tone(buzzer_pin, 850);   // buzzer ON
    return;
  }

  if (cmd == 'z') {
    manual_buzzer_on = false;
    noTone(buzzer_pin);      // buzzer OFF
    return;
  }

  noTone(buzzer_pin);
  buzzer_state = false;

  if (cmd >= '0' && cmd <= '9') {
    int level = cmd - '0';
    speed_val = map(level, 0, 9, 0, 255);
    return;
  }

  if (current_mode == mode_manual || current_mode == mode_teach) {
    if (cmd == 'f' || cmd == 'b' || cmd == 'l' || cmd == 'r' || cmd == 'S') {
      direction = cmd;
    }
    if (current_mode == mode_teach && cmd == 'X') {
      teach_recording = false;
      stop();
      if (step_count < MAX_STEPS) {
        steps[step_count].move = last_move;
        steps[step_count].speed = last_speed;
        steps[step_count].duration = millis() - move_start_time;
        step_count++;
      }
    }
  }
}

// -------------------------------------------------------------
//  ------------------- Motor Functions ------------------------
// -------------------------------------------------------------
void move_forward(int s) {
//  delay(25);
  analogWrite(motor_1_speed, s); analogWrite(motor_2_speed, s);
  digitalWrite(motor_1_f, HIGH); digitalWrite(motor_1_b, LOW);
  digitalWrite(motor_2_f, HIGH); digitalWrite(motor_2_b, LOW);
}
void move_backward(int s) {
//  delay(25);
  analogWrite(motor_1_speed, s); analogWrite(motor_2_speed, s);
  digitalWrite(motor_1_f, LOW); digitalWrite(motor_1_b, HIGH);
  digitalWrite(motor_2_f, LOW); digitalWrite(motor_2_b, HIGH);
}
void move_right(int s) {
  analogWrite(motor_1_speed, s); analogWrite(motor_2_speed, s);
  digitalWrite(motor_1_f, HIGH); digitalWrite(motor_1_b, LOW);
  digitalWrite(motor_2_f, LOW); digitalWrite(motor_2_b, HIGH);
}
void move_left(int s) {
  analogWrite(motor_1_speed, s); analogWrite(motor_2_speed, s);
  digitalWrite(motor_1_f, LOW); digitalWrite(motor_1_b, HIGH);
  digitalWrite(motor_2_f, HIGH); digitalWrite(motor_2_b, LOW);
}
void stop() {
  digitalWrite(motor_1_f, LOW); digitalWrite(motor_1_b, LOW);
  digitalWrite(motor_2_f, LOW); digitalWrite(motor_2_b, LOW);
}

int get_distance(int trigpin, int echopin) {
  digitalWrite(trigpin, LOW); delayMicroseconds(2);
  digitalWrite(trigpin, HIGH); delayMicroseconds(10);
  digitalWrite(trigpin, LOW);
  long duration = pulseIn(echopin, HIGH, 30000UL); 
  if(duration == 0) return 0;
  return duration / 58;
}

void volt_read()
{
  if ( millis() - last_reading >= 500 )
  {
    last_reading = millis();
  
    int val = 0;
    float v_in = 0.0;
    float v_out = 0.0;

    val = analogRead(volt_level);
    v_in = (val * 5.0)/ 1023.0;
    v_out = v_in / (1000.0 / (1000.0+10000.0));
    int send_volt_value = v_out*10; 
    
    if (send_volt_value < 100) Serial.print("0");
    
    Serial.println(send_volt_value);
    
  }
}

void manual_mode() {
  if (direction == 'f') move_forward(speed_val);
  else if (direction == 'b') move_backward(speed_val);
  else if (direction == 'l') move_left(speed_val);
  else if (direction == 'r') move_right(speed_val);
  else stop();
}

// -------------------------------------------------------------
//  -------------- AUTO MODE (SIMPLIFIED STRUCTURE) ------------
// -------------------------------------------------------------

// This function calculates the logic for avoiding obstacles
// It corresponds exactly to your old "avoid_obstacle" function
void avoid_obstacle_logic() {
  
  switch(auto_state) {
    
    // 1. stop(); delay(500);
    case A_STOP_1:
      stop();
      if(check_timer(500)) {
        reset_timer();
        auto_state = A_BACKWARD;
      }
      break;

    // 2. move_backward(150); delay(200);
    case A_BACKWARD:
      move_backward(150);
      if(check_timer(600)) {
        reset_timer();
        auto_state = A_STOP_2;
      }
      break;

    // 3. stop(); delay(500);
    case A_STOP_2:
      stop();
      if(check_timer(500)) {
        servo_1.write(150); // Action for next step
        reset_timer();
        auto_state = A_LOOK_LEFT;
      }
      break;

    // 4. servo_1.write(150); delay(500); 
    //    read left distance
    case A_LOOK_LEFT:
      if(check_timer(500)) {
        obs_left_dist = get_distance(front_trig_pin, front_echo_pin);
        servo_1.write(30); // Action for next step
        reset_timer();
        auto_state = A_LOOK_RIGHT;
      }
      break;

    // 5. servo_1.write(30); delay(500);
    //    read right distance
    case A_LOOK_RIGHT:
      if(check_timer(500)) {
        obs_right_dist = get_distance(front_trig_pin, front_echo_pin);
        servo_1.write(90); // Action for next step
        reset_timer();
        auto_state = A_CENTER_SERVO;
      }
      break;

    // 6. servo_1.write(90); delay(500);
    case A_CENTER_SERVO:
      if(check_timer(500)) {
        reset_timer();
        auto_state = A_TURN;
      }
      break;

    // 7. Logic for turning (delay(200))
    case A_TURN:
      if (obs_left_dist == 0 || obs_right_dist >= obs_left_dist) {
         move_right(255);
      } else {
         move_left(255);
      }
      
      if(check_timer(1000)) {
        reset_timer();
        auto_state = A_STOP_FINAL;
      }
      break;

    // 8. stop(); delay(200);
    case A_STOP_FINAL:
      stop();
      if(check_timer(200)) {
        // Done avoiding! Go back to driving
        auto_state = A_IDLE; 
      }
      break;
  }
}

// This looks like your original auto_mode function!
void auto_mode_non_blocking() {
  
  // If we are currently in the middle of avoiding an obstacle, keep doing it
  if (auto_state != A_IDLE) {
    avoid_obstacle_logic();
    return;
  }

  // Otherwise, normal driving logic
  int front_distance = get_distance(front_trig_pin, front_echo_pin);
  
  if (front_distance > 0 && front_distance < 40) {
     // Start the avoidance sequence
     stop();
     reset_timer();
     auto_state = A_STOP_1; 
  } 
  else {
     move_forward(speed_val);
  }
}

// -------------------------------------------------------------
//  ------------- Non-Blocking Parking Mode --------------------
// -------------------------------------------------------------

void reverse_buzzer() {
  if (millis() - buzzer_timer >= 500) {
    buzzer_timer = millis();
    buzzer_state = !buzzer_state;

    if (buzzer_state) {
      tone(buzzer_pin, 850);   
    } else {
      noTone(buzzer_pin);      
    }
  }
}


void parking_mode_non_blocking() {
  unsigned long now = millis();
  int frontDist = get_distance(front_trig_pin, front_echo_pin);
  int rightDist = get_distance(right_trig_pin, right_echo_pin);
  int leftDist  = get_distance(left_trig_pin, left_echo_pin);
  int backDist  = get_distance(back_trig_pin, back_echo_pin);

  switch (p_state) {
    case S_SEARCHING:
  	move_forward(150);

 	 if (park_side == SIDE_RIGHT) {
    	if (rightDist > 30 && prevRight <= 25) {
	      gapStart = now;
    	  p_state = S_GAP_TIMER;
    	}
  	}
	  else if (park_side == SIDE_LEFT) {
    	if (leftDist > 30 && prevLeft <= 25) {
	      gapStart = now;
    	  p_state = S_GAP_TIMER;
	    }
  	}

	  prevRight = rightDist;
	  prevLeft  = leftDist;
	  break;

    case S_GAP_TIMER:
      move_forward(120);
      if ((park_side == SIDE_RIGHT && rightDist < 20) || (park_side == SIDE_LEFT && leftDist < 20)) {
        p_state = S_SEARCHING;
      }
      if (now - gapStart >= 1000) {
        stop();
        reset_timer(); 
        p_state = S_ALIGN_LEFT;
      }
      break;

    case S_ALIGN_LEFT: 
      if (check_timer(200)) { 
         if (park_side == SIDE_RIGHT) move_left(200);
         else move_right(200);
         reset_timer(); 
         p_state = S_WAIT_1;
      }
      break;

    case S_WAIT_1: 
      if (park_side == SIDE_RIGHT) move_left(200); 
      else move_right(200);
      if (check_timer(1000)) { 
        stop();
        reset_timer();
        p_state = S_REVERSE_IN;
      }
      break;

    case S_REVERSE_IN:
    move_backward(140);
    reverse_buzzer();
    if (backDist > 0 && backDist <= 10) {
      noTone(buzzer_pin);
      buzzer_state = false;
      stop();
      reset_timer();
      p_state = S_STRAIGHTEN;
    }
    break;

    case S_STRAIGHTEN:
      if (check_timer(200)) { 
         if (park_side == SIDE_RIGHT) move_right(200);
         else move_left(200);
         reset_timer();
         p_state = S_WAIT_3;
      }
      break;

    case S_WAIT_3: 
      if (park_side == SIDE_RIGHT) move_right(200);
      else move_left(200);
      if (check_timer(1100)) {
        stop();
        reset_timer();
        p_state = S_FINAL_FORWARD;
      }
      break;

    case S_FINAL_FORWARD:
      if (check_timer(150)) {
        move_forward(140);
        if (frontDist > 0 && frontDist < 20) {
          stop();
          p_state = S_DONE;
        }
      }
      break;

    case S_DONE:
      noTone(buzzer_pin);
      stop();
      break;
  }
}

// -------------------------------------------------------------
//  -------------- Teach & Repeat (Existing) -------------------
// -------------------------------------------------------------
void teach_mode() {
  if (!teach_recording) { manual_mode(); return; }

  if (direction != last_move || speed_val != last_speed) {
    if (step_count < MAX_STEPS) {
      steps[step_count].move = last_move;
      steps[step_count].speed = last_speed;
      steps[step_count].duration = millis() - move_start_time;
      step_count++;
    }
    last_move = direction;
    last_speed = speed_val;
    move_start_time = millis();
  }
  manual_mode();
}

void repeat_mode() {
  if (!repeating) {
    repeat_index = 0;
    repeat_start_time = millis();
    repeating = true;
  }
  if (repeat_index >= step_count) { stop(); return; }

  int repeat_dist = get_distance(front_trig_pin, front_echo_pin);
  if (repeat_dist > 0 && repeat_dist < 40) {
    stop();
    return;
  }


  Step current = steps[repeat_index];
  if (current.move == 'f') move_forward(current.speed);
  else if (current.move == 'b') move_backward(current.speed);
  else if (current.move == 'l') move_left(current.speed);
  else if (current.move == 'r') move_right(current.speed);
  else stop();

  if (millis() - repeat_start_time >= current.duration) {
    repeat_index++;
    repeat_start_time = millis();
  }
}