.syntax unified
.global main

.type main, %function
main:
  @ initialisation
  bl init
  bl BSP_AUDIO_Buffer

  ldr r11, =wave1 @first wave in the sequence 

  mov r0, 2 @next wave in the sequence (wave 2)
  push {r0}

  mov r10, 0 @clear total of wave's current value 

  b song_loop


@restarts the song if counter is reached
@otherwise goes to the next array member
@takes parameter memory location of current wave array in r11
song_loop:
  ldr r1, [r11, 4] @load the length of array  
  ldr r2, [r11, 8] @load the array counter 
  adds r2, 1 
  cmp r2, r1 @check if array counter has gone past length
  bgt reset @if reached the end of the array, reset
  str r2, [r11, 8] @store new array counter

  b calculations

@reset the song loop
reset: 
  @reset each of the wave arrays
  ldr r11, =wave1
  bl reset_loop
  ldr r11, =wave2
  bl reset_loop
  ldr r11, =wave3
  bl reset_loop
  ldr r11, =wave4
  bl reset_loop

  @restart the sequence with wave 1
  ldr r11, =wave1

  @push next wave value onto stack
  mov r0, 2
  push {r0}

  b song_loop

@resets wave array 
@takes parameter memory location of array to reset in r11
reset_loop: 
  push {lr}
  str r0, [r11, 8]
  str r0, [r11, 12]
  str r0, [r11, 16]
  str r0, [r11, 20]
  str r0, [r11, 24]
  str r0, [r11, 28]
  str r0, [r11, 32]
  pop {lr}
  bx lr 

@calculations for the wave 
@takes in parameter r11, the address of the current wave
calculations: 
  @load in current data 
  ldr r0, [r11] @array location
  ldr r3, [r11, 12] @offset for next array value

  ldr r6, [r0, r3] @frequency from data
  adds r3, 4 @add to counter
  ldr r5,  [r0, r3] @time note to be played for
  adds r3, 4 @add to counter

  str r3, [r11, 12] @store offset for next array value

  mov r1, 0 @reset output counter

  str r1, [r11, 16] @update counter
  str r5, [r11, 28] @update time length 

  @check if frequency is 0 (silence)
  cmp r6, 0
  mov r1, 0
  @if it is go to the blank loop
  beq blank_loop

  @based on code from ass1 used to calculate triangle wave sequence
  push {r10} @ save current note value 
  ldr r10, =48000 
  udiv r7, r10, r6 @number of outputs needed for frequency per period
  pop {r10} 
  mov r9, 2
  udiv r7, r7, r9 @number of outputs needed for frequency per half period
  ldr r8, =0x3FFE @range of numbers from peak to trough 
  udiv r8, r8, r7 @number to increase/decrease by

  str r8, [r11, 24] @update scaler 

  mov r0, 2
  str r0, [r11, 32] @update state

  mov r4, 0

  b subloop

@based on code from ass 1
@subtracts from sequence counter until reaches trough 
@takes parameters: output counter: r1 , current note amplitude: r4, 
@scaler value: r8, time length: r5

subloop:
  @add to the total note counter 
  adds r10, r4
  @add to output counter
  add r1, 1
  @move value to be played into r0
  mov r0, r4

  @calculate the next value in the triangle signal
  subs r4, r8

  @store the new r1 and r4 values 
  str r1, [r11, 16]
  str r4, [r11, 20]

  @check if counter has reached desired length
  @if it has, set state to 0
  cmp r1, r5
  ITTT EQ
  moveq r0, 0
  streq r0, [r11, 32]
  beq next_wave

  @cmp value counter (r4) to min value 
  @if it is min value, change the state of the wave to add
  ldr r0, =-0x1fff

  cmp r4, r0
  ITT LE
  movle r0, 1
  strle r0, [r11, 32]

  b next_wave

@based on code from ass 1
@adds to sequence counter until reaches peak 
@takes parameters: output counter: r1 , current note amplitude: r4, 
@scaler value: r8, time length: r5
addloop:
  @add to the total note counter
  adds r10, r4

  @add to the output counter
  add r1, 1

  @ calculate the next value in the triangle signal
  adds r4, r8

  @store the new r1 and r4 values 
  str r1, [r11, 16]
  str r4, [r11, 20]

  cmp r1, r5
  ITTT EQ
  moveq r0, 0
  streq r0, [r11, 32]
  beq next_wave

  @compare counter to max value
  ldr r0, =0x1fff
  cmp r4, r0
  ITT GE
  movge r0, 2
  strge r0, [r11, 32]

  b next_wave

@used for silence 
@takes parameters: output counter: r1 , time length: r5
blank_loop:
  mov r0, 3
  str r0, [r11, 32] @update the state of the wave

  add r1, 1
  str r1, [r11, 16] @update the output counter

  cmp r1, r5 @check if the number of outputs has reached desired time length 
  ITT eq @if it has
  moveq r0, 0 @update the current state  
  streq r0, [r11, 32]

  b next_wave

@goes to the state of the next wave in the sequence
@parameters: next wave number passed on the stack 
next_wave:
  pop {r0}
  cmp r0, 1 @wave 1
  beq play_note

  cmp r0, 2 @wave 2
  ITTTT EQ
  ldreq r11, =wave2 @update r11 with new memory address 
  moveq r0, 3 @update the next wave number 
  pusheq {r0} 
  beq track_state 

  cmp r0, 3 @wave 3
  ITTTT EQ
  ldreq r11, =wave3
  moveq r0, 4
  pusheq {r0}
  beq track_state

  cmp r0, 4 @wave 4
  ITTTT EQ
  ldreq r11, =wave4
  moveq r0, 1
  pusheq {r0}
  beq track_state

  b next_wave

@plays the value stored in r10, which is the addition of the current
@values for each wave
play_note:
  mov r0, r10
  mov r10, 0 @clear r10
  bl BSP_AUDIO_OUT_Play_Sample
  mov r0, 2 @update the next wave number 
  push {r0}
  ldr r11, =wave1 @update r11 with new memory address 
  b track_state

@goes to the correct function based on the wave passed in
@takes in the memory address of the current wave in r11
track_state:
  @state 0 = need to get new note values
  @state 1 = add
  @state 2 = sub
  @state 3 = silence
  ldr r1, [r11, 16]
  ldr r4, [r11, 20]
  ldr r8, [r11, 24]
  ldr r5, [r11, 28]

  ldr r0, [r11, 32] @state
  cmp r0, 0 @need next note
  beq song_loop

  cmp r0, 1 @add loop
  beq addloop

  cmp r0, 2 @sub loop
  beq subloop

  cmp r0, 3 @blank loop
  beq blank_loop


.data
wave1:
  .word track_1 @address of array
  .word 176 @length of array
  .word 0 @array counter
  .word 0 @offset to find the next value of the array
  .word 0 @output counter
  .word 0 @value counter
  .word 0 @value scaler (number to add/subtract)
  .word 0 @time length of wave
  .word 0 @state

wave2:
  .word track_2 @address of array
  .word 292 @length of array
  .word 0 @array counter
  .word 0 @offset to find the next value of the array
  .word 0 @output counter
  .word 0 @value counter
  .word 0 @value scaler (number to add/subtract)
  .word 0 @time length of wave
  .word 0 @state

wave3:
  .word track_3 @address of array
  .word 112 @length of array
  .word 0 @array counter
  .word 0 @offset to find the next value of the array
  .word 0 @output counter
  .word 0 @value counter
  .word 0 @value scaler (number to add/subtract)
  .word 0 @time length of wave
  .word 0 @state

wave4:
  .word track_4 @address of array
  .word 104 @length of array
  .word 0 @array counter
  .word 0 @offset to find the next value of the array
  .word 0 @output counter
  .word 0 @value counter
  .word 0 @value scaler (number to add/subtract)
  .word 0 @time length of wave
  .word 0 @state

@track one (occarina) for Bubblegum KK
track_1:
  .word 0 ,  207360
  .word 147 ,  34512
  .word 0 ,  48
  .word 165 ,  11472
  .word 0 ,  48
  .word 196 ,  11472
  .word 0 ,  48
  .word 165 ,  11472
  .word 0 ,  48
  .word 220 ,  11472
  .word 0 ,  11568
  .word 247 ,  11472
  .word 0 ,  92208
  .word 262 ,  11472
  .word 0 ,  48
  .word 247 ,  11472
  .word 0 ,  48
  .word 196 ,  11472
  .word 0 ,  48
  .word 147 ,  11472
  .word 0 ,  11568
  .word 165 ,  11472
  .word 0 ,  11568
  .word 147 ,  11472
  .word 0 ,  92208
  .word 147 ,  11472
  .word 0 ,  48
  .word 147 ,  11472
  .word 0 ,  48
  .word 165 ,  11472
  .word 0 ,  48
  .word 196 ,  11472
  .word 0 ,  48
  .word 165 ,  11472
  .word 0 ,  48
  .word 220 ,  11472
  .word 0 ,  11568
  .word 247 ,  11472
  .word 0 ,  92208
  .word 262 ,  11472
  .word 0 ,  48
  .word 247 ,  11472
  .word 0 ,  48
  .word 196 ,  11472
  .word 0 ,  48
  .word 147 ,  11472
  .word 0 ,  48
  .word 196 ,  11472
  .word 0 ,  48
  .word 294 ,  17232
  .word 0 ,  109488
  .word 294 ,  11472
  .word 0 ,  48
  .word 294 ,  11472
  .word 0 ,  48
  .word 330 ,  11472
  .word 0 ,  48
  .word 294 ,  11472
  .word 0 ,  48
  .word 262 ,  22992
  .word 0 ,  138288
  .word 262 ,  11472
  .word 0 ,  48
  .word 262 ,  11472
  .word 0 ,  48
  .word 294 ,  11472
  .word 0 ,  48
  .word 262 ,  11472
  .word 0 ,  48
  .word 247 ,  17232
  .word 0 ,  97968
  .word 247 ,  11472
  .word 0 ,  48
  .word 247 ,  11472
  .word 0 ,  48
  .word 262 ,  11472
  .word 0 ,  48
  .word 294 ,  11472
  .word 0 ,  48
  .word 196 ,  11472
  .word 0 ,  48
  .word 220 ,  11472
  .word 0 ,  115248
  .word 220 ,  11472
  .word 0 ,  48
  .word 220 ,  11472
  .word 0 ,  48
  .word 196 ,  11472
  .word 0 ,  48
  .word 185 ,  11472
  .word 0 ,  48
  .word 220 ,  11472
  .word 0 ,  48
  .word 196 ,  17232
  .word 0 ,  97968
  .word 196 ,  11472
  .word 0 ,  11568
  .word 185 ,  11472
  .word 0 ,  11568
  .word 165 ,  11472
  .word 0 ,  11568
  .word 185 ,  11472
  .word 0 ,  48
  .word 185 ,  11472
  .word 0 ,  48
  .word 185 ,  11472
  .word 0 ,  48
  .word 185 ,  34512
  .word 0 ,  23088
  .word 185 ,  11472
  .word 0 ,  48
  .word 185 ,  11472
  .word 0 ,  48
  .word 185 ,  11472
  .word 0 ,  48
  .word 185 ,  11472
  .word 0 ,  48
  .word 185 ,  11472
  .word 0 ,  48
  .word 147 ,  11472
  .word 0 ,  48
  .word 123 ,  11472
  .word 0 ,  48
  .word 165 ,  92112
  .word 0 ,  80688
  .word 147 ,  11472
  .word 0 ,  48
  .word 165 ,  11472
  .word 0 ,  48
  .word 185 ,  11472
  .word 0 ,  48
  .word 185 ,  11472
  .word 0 ,  48
  .word 185 ,  11472
  .word 0 ,  48
  .word 185 ,  34512
  .word 0 ,  23088
  .word 185 ,  11472
  .word 0 ,  48
  .word 185 ,  11472
  .word 0 ,  48
  .word 185 ,  11472
  .word 0 ,  48
  .word 185 ,  11472
  .word 0 ,  48
  .word 185 ,  11472
  .word 0 ,  48
  .word 220 ,  11472
  .word 0 ,  11568
  .word 165 ,  92112
  .word 0 ,  80688
  .word 165 ,  11472
  .word 0 ,  48
  .word 185 ,  11472
  .word 0 ,  48
  .word 196 ,  11472
  .word 0 ,  48
  .word 196 ,  11472
  .word 0 ,  48
  .word 196 ,  11472
  .word 0 ,  48
  .word 196 ,  34512
  .word 0 ,  23088
  .word 196 ,  11472
  .word 0 ,  48
  .word 196 ,  11472
  .word 0 ,  48
  .word 196 ,  11472
  .word 0 ,  48
  .word 196 ,  22992
  .word 0 ,  48
  .word 196 ,  11472
  .word 0 ,  48
  .word 185 ,  11472
  .word 0 ,  48
  .word 147 ,  22992

@track 2: bass guitar for Bubblegum KK
track_2:
  .word 0 ,  11520
  .word 98 ,  11472
  .word 0 ,  23088
  .word 98 ,  11472
  .word 0 ,  48
  .word 131 ,  11472
  .word 0 ,  11568
  .word 131 ,  11472
  .word 0 ,  11568
  .word 110 ,  11472
  .word 0 ,  48
  .word 123 ,  11472
  .word 0 ,  48
  .word 131 ,  11472
  .word 0 ,  48
  .word 147 ,  22992
  .word 0 ,  126768
  .word 98 ,  11472
  .word 0 ,  23088
  .word 98 ,  11472
  .word 0 ,  48
  .word 98 ,  22992
  .word 0 ,  23088
  .word 131 ,  11472
  .word 0 ,  23088
  .word 131 ,  11472
  .word 0 ,  48
  .word 131 ,  22992
  .word 0 ,  23088
  .word 98 ,  11472
  .word 0 ,  23088
  .word 98 ,  11472
  .word 0 ,  48
  .word 98 ,  22992
  .word 0 ,  23088
  .word 131 ,  11472
  .word 0 ,  23088
  .word 131 ,  11472
  .word 0 ,  48
  .word 131 ,  22992
  .word 0 ,  23088
  .word 98 ,  11472
  .word 0 ,  23088
  .word 98 ,  11472
  .word 0 ,  48
  .word 98 ,  22992
  .word 0 ,  23088
  .word 131 ,  11472
  .word 0 ,  23088
  .word 131 ,  11472
  .word 0 ,  48
  .word 131 ,  22992
  .word 0 ,  23088
  .word 123 ,  11472
  .word 0 ,  23088
  .word 123 ,  11472
  .word 0 ,  48
  .word 123 ,  22992
  .word 0 ,  23088
  .word 165 ,  11472
  .word 0 ,  23088
  .word 165 ,  11472
  .word 0 ,  48
  .word 165 ,  22992
  .word 0 ,  23088
  .word 110 ,  11472
  .word 0 ,  23088
  .word 110 ,  11472
  .word 0 ,  48
  .word 110 ,  22992
  .word 0 ,  23088
  .word 147 ,  11472
  .word 0 ,  23088
  .word 147 ,  11472
  .word 0 ,  48
  .word 147 ,  22992
  .word 0 ,  23088
  .word 98 ,  11472
  .word 0 ,  23088
  .word 98 ,  11472
  .word 0 ,  48
  .word 98 ,  22992
  .word 0 ,  23088
  .word 165 ,  11472
  .word 0 ,  23088
  .word 165 ,  11472
  .word 0 ,  48
  .word 165 ,  22992
  .word 0 ,  23088
  .word 110 ,  11472
  .word 0 ,  23088
  .word 110 ,  11472
  .word 0 ,  48
  .word 110 ,  22992
  .word 0 ,  23088
  .word 147 ,  11472
  .word 0 ,  23088
  .word 147 ,  11472
  .word 0 ,  48
  .word 147 ,  22992
  .word 0 ,  23088
  .word 98 ,  11472
  .word 0 ,  23088
  .word 98 ,  11472
  .word 0 ,  48
  .word 104 ,  22992
  .word 0 ,  48
  .word 104 ,  11472
  .word 0 ,  48
  .word 98 ,  11472
  .word 0 ,  23088
  .word 147 ,  11472
  .word 0 ,  11568
  .word 139 ,  11472
  .word 0 ,  11568
  .word 131 ,  11472
  .word 0 ,  11568
  .word 123 ,  11472
  .word 0 ,  48
  .word 123 ,  11472
  .word 0 ,  48
  .word 123 ,  11472
  .word 0 ,  48
  .word 123 ,  11472
  .word 0 ,  48
  .word 123 ,  11472
  .word 0 ,  48
  .word 123 ,  11472
  .word 0 ,  48
  .word 123 ,  11472
  .word 0 ,  48
  .word 123 ,  11472
  .word 0 ,  48
  .word 123 ,  11472
  .word 0 ,  48
  .word 123 ,  11472
  .word 0 ,  48
  .word 123 ,  11472
  .word 0 ,  48
  .word 123 ,  11472
  .word 0 ,  48
  .word 123 ,  11472
  .word 0 ,  48
  .word 123 ,  11472
  .word 0 ,  48
  .word 123 ,  11472
  .word 0 ,  48
  .word 147 ,  11472
  .word 0 ,  48
  .word 165 ,  11472
  .word 0 ,  48
  .word 165 ,  11472
  .word 0 ,  48
  .word 165 ,  11472
  .word 0 ,  48
  .word 165 ,  11472
  .word 0 ,  48
  .word 165 ,  11472
  .word 0 ,  48
  .word 165 ,  11472
  .word 0 ,  48
  .word 165 ,  11472
  .word 0 ,  48
  .word 165 ,  11472
  .word 0 ,  48
  .word 165 ,  11472
  .word 0 ,  48
  .word 196 ,  11472
  .word 0 ,  48
  .word 247 ,  11472
  .word 0 ,  48
  .word 196 ,  11472
  .word 0 ,  48
  .word 330 ,  11472
  .word 0 ,  48
  .word 247 ,  11472
  .word 0 ,  48
  .word 196 ,  11472
  .word 0 ,  48
  .word 165 ,  11472
  .word 0 ,  48
  .word 123 ,  11472
  .word 0 ,  48
  .word 123 ,  11472
  .word 0 ,  48
  .word 123 ,  11472
  .word 0 ,  48
  .word 123 ,  11472
  .word 0 ,  48
  .word 123 ,  11472
  .word 0 ,  48
  .word 123 ,  11472
  .word 0 ,  48
  .word 123 ,  11472
  .word 0 ,  48
  .word 123 ,  11472
  .word 0 ,  48
  .word 123 ,  11472
  .word 0 ,  48
  .word 123 ,  11472
  .word 0 ,  48
  .word 123 ,  11472
  .word 0 ,  48
  .word 123 ,  11472
  .word 0 ,  48
  .word 123 ,  11472
  .word 0 ,  48
  .word 123 ,  11472
  .word 0 ,  48
  .word 123 ,  11472
  .word 0 ,  48
  .word 147 ,  11472
  .word 0 ,  48
  .word 165 ,  11472
  .word 0 ,  48
  .word 165 ,  11472
  .word 0 ,  48
  .word 165 ,  11472
  .word 0 ,  48
  .word 165 ,  11472
  .word 0 ,  48
  .word 165 ,  11472
  .word 0 ,  48
  .word 165 ,  11472
  .word 0 ,  48
  .word 165 ,  11472
  .word 0 ,  48
  .word 165 ,  11472
  .word 0 ,  48
  .word 165 ,  11472
  .word 0 ,  48
  .word 196 ,  11472
  .word 0 ,  48
  .word 247 ,  11472
  .word 0 ,  48
  .word 196 ,  11472
  .word 0 ,  48
  .word 330 ,  11472
  .word 0 ,  48
  .word 247 ,  11472
  .word 0 ,  48
  .word 196 ,  11472
  .word 0 ,  48
  .word 165 ,  11472
  .word 0 ,  48
  .word 131 ,  11472
  .word 0 ,  48
  .word 131 ,  11472
  .word 0 ,  48
  .word 131 ,  11472
  .word 0 ,  48
  .word 131 ,  11472
  .word 0 ,  48
  .word 131 ,  11472
  .word 0 ,  48
  .word 131 ,  11472
  .word 0 ,  48
  .word 131 ,  11472
  .word 0 ,  48
  .word 131 ,  11472
  .word 0 ,  48
  .word 156 ,  11472
  .word 0 ,  48
  .word 156 ,  11472
  .word 0 ,  48
  .word 156 ,  11472
  .word 0 ,  48
  .word 156 ,  11472
  .word 0 ,  48
  .word 156 ,  11472
  .word 0 ,  48
  .word 156 ,  11472
  .word 0 ,  48
  .word 156 ,  11472
  .word 0 ,  48
  .word 156 ,  11472
  .word 0 ,  48
  .word 147 ,  11472
  .word 0 ,  48
  .word 147 ,  22992
  .word 0 ,  48
  .word 294 ,  11472
  .word 0 ,  48
  .word 294 ,  17232
  .word 0 ,  48
  .word 262 ,  17232
  .word 0 ,  48
  .word 220 ,  11472
  .word 0 ,  48
  .word 185 ,  22992
  .word 0 ,  48
  .word 147 ,  11472

@track 3: music box for Bubblegum KK
track_3:
  .word 0 ,  11520
  .word 392 ,  11472
  .word 0 ,  11568
  .word 294 ,  11472
  .word 0 ,  11568
  .word 523 ,  11472
  .word 0 ,  48
  .word 494 ,  11472
  .word 0 ,  48
  .word 440 ,  11472
  .word 0 ,  48
  .word 392 ,  11472
  .word 0 ,  48
  .word 440 ,  11472
  .word 0 ,  48
  .word 494 ,  11472
  .word 0 ,  48
  .word 523 ,  11472
  .word 0 ,  48
  .word 587 ,  22992
  .word 0 ,  5808
  .word 440 ,  2832
  .word 0 ,  48
  .word 494 ,  2832
  .word 0 ,  48
  .word 523 ,  2832
  .word 0 ,  48
  .word 587 ,  8592
  .word 0 ,  322608
  .word 523 ,  11472
  .word 0 ,  48
  .word 494 ,  11472
  .word 0 ,  48
  .word 392 ,  11472
  .word 0 ,  48
  .word 294 ,  11472
  .word 0 ,  11568
  .word 330 ,  11472
  .word 0 ,  48
  .word 392 ,  11472
  .word 0 ,  48
  .word 440 ,  11472
  .word 0 ,  48
  .word 392 ,  11472
  .word 0 ,  276528
  .word 494 ,  34512
  .word 0 ,  48
  .word 494 ,  3744
  .word 0 ,  48
  .word 466 ,  3744
  .word 0 ,  96
  .word 440 ,  3744
  .word 0 ,  144
  .word 415 ,  69072
  .word 0 ,  46128
  .word 659 ,  22992
  .word 0 ,  48
  .word 740 ,  22992
  .word 0 ,  8688
  .word 740 ,  2832
  .word 0 ,  48
  .word 784 ,  5712
  .word 0 ,  48
  .word 740 ,  5712
  .word 0 ,  115248
  .word 784 ,  22992
  .word 0 ,  48
  .word 880 ,  11472
  .word 0 ,  23088
  .word 988 ,  2832
  .word 0 ,  48
  .word 1047 ,  2832
  .word 0 ,  48
  .word 988 ,  11472
  .word 0 ,  109488
  .word 659 ,  22992
  .word 0 ,  48
  .word 740 ,  22992
  .word 0 ,  8688
  .word 740 ,  2832
  .word 0 ,  48
  .word 784 ,  5712
  .word 0 ,  48
  .word 740 ,  5712
  .word 0 ,  46128
  .word 880 ,  11472
  .word 0 ,  48
  .word 784 ,  11472
  .word 0 ,  48
  .word 740 ,  11472
  .word 0 ,  48
  .word 880 ,  11472
  .word 0 ,  48
  .word 784 ,  11472
  .word 0 ,  103728
  .word 392 ,  11472
  .word 0 ,  11568
  .word 370 ,  11472
  .word 0 ,  11568
  .word 330 ,  11472
  .word 0 ,  944688
  .word 294 ,  22992
  .word 0 ,  48
  .word 330 ,  11472
  .word 0 ,  48
  .word 370 ,  17232
  .word 0 ,  48
  .word 392 ,  17232
  .word 0 ,  48
  .word 440 ,  11472
  .word 0 ,  48
  .word 587 ,  22992

@track 3: bright piano for Bubblegum KK
track_4:
  .word 0 ,  11520
  .word 147 ,  10896
  .word 0 ,  23664
  .word 147 ,  10896
  .word 0 ,  624
  .word 165 ,  10896
  .word 0 ,  12144
  .word 165 ,  10896
  .word 0 ,  12144
  .word 165 ,  10896
  .word 0 ,  624
  .word 165 ,  10896
  .word 0 ,  12144
  .word 185 ,  21840
  .word 0 ,  865200
  .word 165 ,  10896
  .word 0 ,  23664
  .word 165 ,  10896
  .word 0 ,  624
  .word 165 ,  21840
  .word 0 ,  24240
  .word 185 ,  10896
  .word 0 ,  23664
  .word 185 ,  10896
  .word 0 ,  624
  .word 185 ,  21840
  .word 0 ,  24240
  .word 185 ,  10896
  .word 0 ,  23664
  .word 185 ,  10896
  .word 0 ,  624
  .word 185 ,  21840
  .word 0 ,  24240
  .word 196 ,  10896
  .word 0 ,  23664
  .word 196 ,  10896
  .word 0 ,  624
  .word 196 ,  21840
  .word 0 ,  24240
  .word 165 ,  10896
  .word 0 ,  23664
  .word 165 ,  10896
  .word 0 ,  624
  .word 165 ,  21840
  .word 0 ,  24240
  .word 185 ,  10896
  .word 0 ,  23664
  .word 185 ,  10896
  .word 0 ,  624
  .word 185 ,  21840
  .word 0 ,  24240
  .word 147 ,  10896
  .word 0 ,  23664
  .word 147 ,  10896
  .word 0 ,  624
  .word 156 ,  21840
  .word 0 ,  1200
  .word 156 ,  10896
  .word 0 ,  624
  .word 147 ,  10896
  .word 0 ,  104304
  .word 147 ,  10896
  .word 0 ,  12144
  .word 147 ,  10896
  .word 0 ,  12144
  .word 147 ,  10896
  .word 0 ,  12144
  .word 147 ,  10896
  .word 0 ,  12144
  .word 147 ,  10896
  .word 0 ,  12144
  .word 147 ,  10896
  .word 0 ,  12144
  .word 147 ,  10896
  .word 0 ,  219504
  .word 147 ,  10896
  .word 0 ,  12144
  .word 147 ,  10896
  .word 0 ,  12144
  .word 147 ,  10896
  .word 0 ,  12144
  .word 147 ,  10896
  .word 0 ,  12144
  .word 147 ,  10896
  .word 0 ,  12144
  .word 147 ,  10896
  .word 0 ,  12144
  .word 147 ,  10896
  .word 0 ,  219504
  .word 131 ,  10896
  .word 0 ,  12144
  .word 131 ,  10896
  .word 0 ,  12144
  .word 131 ,  10896
  .word 0 ,  12144
  .word 131 ,  10896
  .word 0 ,  12144
  .word 156 ,  10896
  .word 0 ,  12144
  .word 156 ,  10896
  .word 0 ,  12144
  .word 156 ,  10896
  .word 0 ,  12144
  .word 156 ,  10896