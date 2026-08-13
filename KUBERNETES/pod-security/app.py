import time

def countdown_app(seconds):
    print("🚀 Timer started!")
    
    for i in range(seconds, 0, -1):
        print(f"Time remaining: {i} seconds...")
        # Pause execution for exactly 1 second
        time.sleep(1) 
        
    print("🎉 Time's up!")

# Run the app with a 5-second countdown
countdown_app(3600)
