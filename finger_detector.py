import cv2
import mediapipe as mp
import math
from pythonosc import udp_client

# OSC setup
OSC_IP = "127.0.0.1"
OSC_PORT = 6448
OSC_ADDR = "/hand/features"

# MediaPipe hand landmark indices
WRIST = 0
THUMB_TIP = 4
INDEX_TIP = 8
MIDDLE_TIP = 12
RING_TIP = 16
PINKY_TIP = 20
INDEX_MCP = 5

def euclidean(a, b):
    return math.sqrt((a.x - b.x) ** 2 + (a.y - b.y) ** 2 + (a.z - b.z) ** 2)

def normalized_dist(lm, tip_idx, thumb_idx, ref_idx):
    hand_size = euclidean(lm[WRIST], lm[ref_idx])
    if hand_size < 1e-6:
        return 0.0
    return euclidean(lm[tip_idx], lm[thumb_idx]) / hand_size

def main():
    client = udp_client.SimpleUDPClient(OSC_IP, OSC_PORT)

    camera = cv2.VideoCapture(0)

    if not camera.isOpened():
        raise RuntimeError("Could not open webcam.")

    print(f"Sending OSC to {OSC_IP}:{OSC_PORT}  address={OSC_ADDR}")

    with mp.solutions.hands.Hands(
        model_complexity=0,  # 0 = fast, 1 = accurate
        max_num_hands=1,
        min_detection_confidence=0.7,
        min_tracking_confidence=0.6,
    ) as hands:

        while camera.isOpened():
            ok, frame = camera.read()
            if not ok:
                break

            # MediaPipe expects RGB
            frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            frame_rgb.flags.writeable = False
            results = hands.process(frame_rgb)
            frame_rgb.flags.writeable = True
            frame = cv2.cvtColor(frame_rgb, cv2.COLOR_RGB2BGR)

            if results.multi_hand_landmarks is not None:
                # Use the first detected hand
                hand_lm = results.multi_hand_landmarks[0]
                lm = hand_lm.landmark

                # Compute normalized finger-to-thumb distances
                d_index = normalized_dist(lm, INDEX_TIP, THUMB_TIP, INDEX_MCP)
                d_middle = normalized_dist(lm, MIDDLE_TIP, THUMB_TIP, INDEX_MCP)
                d_ring = normalized_dist(lm, RING_TIP, THUMB_TIP, INDEX_MCP)
                d_pinky = normalized_dist(lm, PINKY_TIP, THUMB_TIP, INDEX_MCP)

                client.send_message("/hand/present", [1.0]) # 1.0 means present
                client.send_message(OSC_ADDR, [d_index, d_middle, d_ring, d_pinky])

                # draw landmarks on frame
                mp.solutions.drawing_utils.draw_landmarks(
                    frame,
                    hand_lm,
                    mp.solutions.hands.HAND_CONNECTIONS,
                    mp.solutions.drawing_styles.get_default_hand_landmarks_style(),
                    mp.solutions.drawing_styles.get_default_hand_connections_style(),
                )
            else:
                client.send_message("/hand/present", [0.0]) # 0.0 means not present
                client.send_message(OSC_ADDR, [0.0, 0.0, 0.0, 0.0])

            cv2.imshow("Hand Tracker  (Q to quit)", frame)
            if cv2.waitKey(1) & 0xFF == ord("q"):
                break

    camera.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    main()