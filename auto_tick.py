import argparse
import subprocess
import time
import sys

def parse_arguments():
    parser = argparse.ArgumentParser(description='Monitor and manage Qubic nodes.')
    parser.add_argument('-n', type=int, default=1, help='Interval in minutes (default: 1)')
    parser.add_argument('-node_ips', required=True, help='Comma-separated list of node IPs')
    parser.add_argument('-node_ports', default='', help='Comma-separated list of node ports (default: 31841 for all)')
    parser.add_argument('-ticks_per_epoch', type=int, required=True, help='Number of ticks per epoch')
    args = parser.parse_args()

    node_ips = args.node_ips.split(',')
    node_ports = args.node_ports.split(',') if args.node_ports else ['31841'] * len(node_ips)

    if len(node_ips) != len(node_ports):
        print("Error: The number of node IPs and node ports must be the same.")
        sys.exit(1)

    return args.n, node_ips, node_ports, args.ticks_per_epoch

def run_command(command):
    try:
        result = subprocess.check_output(command, shell=True, stderr=subprocess.STDOUT, universal_newlines=True)
        return result.strip()
    except subprocess.CalledProcessError as e:
        return e.output.strip()

def parse_tick_info(output):
    lines = output.split('\n')
    info = {}
    for line in lines:
        if line.startswith('Tick:'):
            info['latestTick'] = int(line.split('Tick:')[1].strip())
        elif line.startswith('Epoch:'):
            info['currentEpoch'] = int(line.split('Epoch:')[1].strip())
        elif line.startswith('Initial tick:'):
            info['initialTick'] = int(line.split('Initial tick:')[1].strip())
    return info

def main():
    n, node_ips, node_ports, ticks_per_epoch = parse_arguments()
    seed = '' # Add seed to do the autotick here
    interval_seconds = n * 60

    unchanged_count = 0
    previous_info = {}
    last_iteration_triggered_action_1 = False
    last_iteration_triggered_action_4 = False

    while True:
        current_info = {}
        error_occurred = False

        # Step 1: Get current tick info from the first node
        nodeip1 = node_ips[0]
        port1 = node_ports[0]
        cmd_get_tick = f'./qubic-cli -nodeip {nodeip1} -nodeport {port1} -getcurrenttick'
        output = run_command(cmd_get_tick)

        if 'Error' in output or 'Failed' in output:
            error_occurred = True
            current_info = previous_info.copy()
            print(output)
        else:
            tick_info = parse_tick_info(output)
            if not tick_info:
                error_occurred = True
                print("Failed to parse tick info.")
            else:
                current_info = tick_info

        # Compare with previous info
        if current_info == previous_info and current_info:
            unchanged_count += 1
            tick_unchanged = True
        else:
            unchanged_count = 0
            tick_unchanged = False

        previous_info = current_info.copy()

        # Calculate end tick
        if current_info:
            end_tick = current_info['initialTick'] + ticks_per_epoch - 50

        print(f"Current info: {current_info}, end tick: {end_tick}, if exceeded end tick: {current_info.get('latestTick', 0) > end_tick}, distance to end tick: {end_tick - current_info.get('latestTick', 0)}")
        # Initialize action triggers for this iteration
        action_1_triggered = False
        action_2_triggered = False
        action_4_triggered = False

        # Check conditions after 3 intervals or error
        if unchanged_count >= 3 or error_occurred:
            # Condition 1: If current tick > end tick, run broadcastComputorTestnet 5 times
            if current_info.get('latestTick', 0) > end_tick:
                for _ in range(5):
                    cmd_broadcast = f'./broadcastComputorTestnet {nodeip1} {current_info["currentEpoch"] + 1} {port1}'
                    print(f'Executing: {cmd_broadcast}')
                    run_command(cmd_broadcast)
                action_1_triggered = True

            # Condition 2: Run tooglemainaux to MAINMAIN or Mainaux for each node after Condition 1 was triggered
            if action_1_triggered:
                for ip, port in zip(node_ips, node_ports):
                    cmd_toggle = f'./qubic-cli -seed {seed} -nodeip {ip} -nodeport {port} -tooglemainaux MAIN MAIN' # Depends on your need, change MAIN MAIN to MAIN AUX if needed
                    print(f'Executing: {cmd_toggle}')
                    run_command(cmd_toggle)
                action_2_triggered = True

            # Condition 3: Trigger refreshpeerlist if Condition 1 or Condition 4 was triggered in the last iteration and tick hasn't changed
            if (last_iteration_triggered_action_1 or last_iteration_triggered_action_4) and tick_unchanged:
                for ip, port in zip(node_ips, node_ports):
                    cmd_refresh = f'./qubic-cli -seed {seed} -nodeip {ip} -nodeport {port} -refreshpeerlist'
                    print(f'Executing: {cmd_refresh}')
                    run_command(cmd_refresh)
                condition_3_triggered = True
            else:
                condition_3_triggered = False

            # Condition 4: Run reissuevote for each node
            for ip, port in zip(node_ips, node_ports):
                cmd_reissue = f'./qubic-cli -seed {seed} -nodeip {ip} -nodeport {port} -reissuevote'
                print(f'Executing: {cmd_reissue}')
                run_command(cmd_reissue)
            action_4_triggered = True

            # Sleep time determination
            if condition_3_triggered:
                sleep_time = 45 * 60  # Sleep for 45 minutes
            else:
                sleep_time = 2 * 60   # Sleep for 2 minutes

            # Update last iteration action statuses
            last_iteration_triggered_action_1 = action_1_triggered
            last_iteration_triggered_action_4 = action_4_triggered

            time.sleep(sleep_time)
        else:
            # Not enough unchanged intervals yet, wait for the next interval
            # Reset last iteration action statuses
            last_iteration_triggered_action_1 = False
            last_iteration_triggered_action_4 = False

            time.sleep(interval_seconds)

if __name__ == '__main__':
    main()

