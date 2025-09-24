#!/bin/bash

pde=wave
loss=mse
n_layers=4
num_x=257
num_t=101
num_res=10000
opt=adam
epochs=41000
beta=5
devices=(0 1)
proj=wave_adam_final
max_parallel_jobs=4

background_pids=()
current_device=0
interrupted=0

cleanup() {
    echo "Interrupt received, stopping background jobs..."
    interrupted=1
    for pid in "${background_pids[@]}"; do
        kill $pid 2>/dev/null
    done
}
trap cleanup SIGINT

# --- Недостающие 31 комбинация ---
seeds=(234 345 345 345 345 345 345 345 345 345 345 345 345 345 456 456 456 456 456 456 456 456 567 567 567 567 567 567 567 567 567)
n_neurons=(400 50 50 50 50 100 100 100 100 200 200 200 200 400 50 100 100 200 200 200 400 400 50 100 100 200 200 200 400 400 400)
adam_lrs=(0.1 0.00001 0.0001 0.001 0.01 0.00001 0.0001 0.001 0.01 0.00001 0.0001 0.001 0.01 0.00001 0.1 0.01 0.1 0.001 0.01 0.1 0.01 0.1 0.1 0.001 0.01 0.1 0.001 0.01 0.001 0.01 0.1)
# --------------------------------

for i in "${!seeds[@]}"; do
    if [ $interrupted -eq 0 ]; then
        seed=${seeds[$i]}
        n_neuron=${n_neurons[$i]}
        adam_lr=${adam_lrs[$i]}

        device=${devices[current_device]}
        current_device=$(( (current_device + 1) % ${#devices[@]} ))

        echo "Запуск: seed=$seed, n_neurons=$n_neuron, adam_lr=$adam_lr на device=$device"

        python run_experiment.py \
            --seed $seed --pde $pde --pde_params beta $beta --opt $opt \
            --opt_params lr $adam_lr --num_layers $n_layers --num_neurons $n_neuron \
            --loss $loss --num_x $num_x --num_t $num_t --num_res $num_res \
            --epochs $epochs --wandb_project $proj --device $device &

        background_pids+=($!)

        while [ $(jobs | wc -l) -ge $max_parallel_jobs ]; do
            wait -n
            for j in ${!background_pids[@]}; do
                if ! kill -0 ${background_pids[$j]} 2> /dev/null; then
                    unset 'background_pids[$j]'
                fi
            done
        done
    fi
done

wait
cleanup
