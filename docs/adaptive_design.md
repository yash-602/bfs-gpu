# Adaptive scheme: design, tuning and final defaults (OWNER: Member 3)

> **PLACEHOLDER-NOT-YET-DELIVERED (Member 3, hand-off H7)**
>
> MEMBER 3: replace this whole file (playbook sections 9.9 and 9.14). It must contain:
> - the chosen default `warp_thresh`, `block_thresh`, `block_size`, `bucket_mode`, with the reasons
> - the full threshold grid (warp 8..128 x block 512..4096), tuned with `--seed 2`, including the bad regions
> - known limitations and ideas you did not do
>
> If the defaults change, also change `include/bfs_api.h` through the contract procedure
> (playbook section 3.4: post the change, both others agree, Member 1 applies it and bumps CONTRACT_VERSION).
