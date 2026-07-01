enum VoiceState {
  idle, // Waiting for user input
  listening, // Microphone is ON
  processing, // Sending/Receiving from Backend
  speaking, // AI Voice is playing
  error, // Something went wrong
}
