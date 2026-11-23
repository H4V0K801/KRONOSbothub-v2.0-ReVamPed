#include-once
; ==============================================================================================
; GWBridge_Layout.au3 - AutoIt mirror of src/dll/gwbridge_layout.h (layout version 1).
; Any change here MUST match the C header; GWBridge_Attach() refuses to attach on a mismatch.
; ==============================================================================================
Global Const $GWB_MAGIC = 0x52425747
Global Const $GWB_LAYOUT_VERSION = 1
Global Const $GWB_HEADER_SIZE = 256
Global Const $GWB_TOTAL_SIZE = 311072
Global Const $GWB_SLOT_OFFSET0 = 256, $GWB_SLOT_OFFSET1 = 137088, $GWB_SLOT_SIZE = 136832
Global Const $GWB_BAG_OFFSET0 = 273920, $GWB_BAG_OFFSET1 = 290416, $GWB_BAG_SLOT_SIZE = 16496
Global Const $GWB_CMD_OFFSET = 306912, $GWB_CMD_CAPACITY = 64, $GWB_CMD_ENTRY_SIZE = 64

; slot section offsets
Global Const $GWB_SLOT_CORE_COPY = 2688          ; bytes copied by one snapshot: core+party+skillbars+recharge+me
Global Const $GWB_SLOT_OFF_SKILLBARS = 448, $GWB_SKILLBAR_RAW = 188
Global Const $GWB_SLOT_OFF_ME = 2208
Global Const $GWB_SLOT_OFF_HASH = 2688, $GWB_HASH_SIZE = 512
Global Const $GWB_SLOT_OFF_DIR = 3712, $GWB_MAX_DIR = 1024
Global Const $GWB_SLOT_OFF_AGENTS = 20096, $GWB_AGENT_STRIDE = 456, $GWB_MAX_AGENTS = 256
; bag slot
Global Const $GWB_BAG_OFF_INFO = 32, $GWB_BAG_INFO_SIZE = 56, $GWB_BAG_OFF_ITEMS = 368
Global Const $GWB_BAG_SLOTS = 32, $GWB_ITEM_RAW = 84, $GWB_BAG_RAW = 40
Global Const $GWB_BAG_IDS[6] = [1, 2, 3, 4, 5, 22]

; header.status
Global Const $GWB_ST_MAPPED = 0x1, $GWB_ST_GWCA_LOADED = 0x2, $GWB_ST_GWCA_INIT = 0x4, $GWB_ST_HOOKED = 0x8
Global Const $GWB_ST_RUNNING = 0x10, $GWB_ST_STUB = 0x20, $GWB_ST_UNLOADING = 0x40, $GWB_ST_ERROR = 0x80, $GWB_ST_STALLED = 0x100
; header.last_error values (gwbridge_layout.h)
Global Const $GWB_ERR_NOT_GW = 6, $GWB_ERR_FOREIGN_TOOL = 7
; slot.flags
Global Const $GWB_SF_MAP_LOADED = 0x1, $GWB_SF_PLAYER_VALID = 0x2, $GWB_SF_LOADING = 0x4, $GWB_SF_PARTY_VALID = 0x8
Global Const $GWB_SF_DEAD = 0x10, $GWB_SF_TRUNCATED = 0x20, $GWB_SF_DIR_TRUNC = 0x40, $GWB_SF_SKIPPED = 0x80
; opcodes
Global Const $GWB_OP_NOP = 0, $GWB_OP_PING = 1, $GWB_OP_MOVE = 2, $GWB_OP_USE_SKILL = 3, $GWB_OP_USE_SKILL_ID = 4
Global Const $GWB_OP_CHANGE_TARGET = 5, $GWB_OP_INTERACT = 6, $GWB_OP_PICK_UP = 7, $GWB_OP_USE_ITEM = 8
Global Const $GWB_OP_DIALOG = 9, $GWB_OP_UNLOAD = 15
; command states
Global Const $GWB_CS_FREE = 0, $GWB_CS_QUEUED = 1, $GWB_CS_DONE = 2, $GWB_CS_FAILED = 3, $GWB_CS_REJECTED = 4, $GWB_CS_UNKNOWN_OP = 5

Global Const $GWB_HEADER_TEMPLATE = _
	'dword magic;dword layout_version;dword header_size;dword total_size;dword slot_offset0;dword slot_offset1;' & _
	'dword slot_size;dword bag_offset0;dword bag_offset1;dword bag_slot_size;dword cmd_offset;dword cmd_capacity;' & _
	'dword cmd_entry_size;dword current_slot;dword frame_counter;dword heartbeat_tick;dword status;dword last_error;' & _
	'dword game_pid;dword gwca_abi;dword gw_version;dword skipped_frames;dword last_skip_reason;dword frame_cost_us_avg;' & _
	'dword frame_cost_us_max;dword current_bag_slot;dword bag_counter;dword game_thread_ok;float agent_range;' & _
	'dword cmds_per_frame;dword client_pid;dword control_flags;char build[32];char diag[64];dword reserved[8]'

; the part of a slot copied in one RtlMoveMemory (2688 bytes)
Global Const $GWB_CORE_TEMPLATE = _
	'dword seq;dword frame_id;dword tick;dword flags;dword map_id;dword instance_type;dword instance_time;dword my_id;' & _
	'dword target_id;dword skill_timer;dword agent_count;dword dir_count;dword max_agents;float range;float my_x;float my_y;' & _
	'float my_hp;float my_energy;dword my_max_hp;dword my_max_energy;dword my_effects;dword my_model_state;dword my_skill;' & _
	'dword my_plane;dword party_flags;dword player_count;dword hero_count;dword hench_count;dword skillbar_count;' & _
	'int district;dword region;dword reserved[33];' & _
	'dword heroes[32];dword player_agents[8];dword hench_agents[8];byte skillbars[1504];dword recharge_ms[64];' & _
	'byte me[456];byte pad0[24]'

Global Const $GWB_CMD_RING_TEMPLATE = 'dword write_idx;dword read_idx;dword last_done_id;dword done_count;dword fail_count;dword reserved[11]'
Global Const $GWB_CMD_TEMPLATE = 'dword state;dword id;dword op;dword arg[8];int result;dword done_frame;dword reserved[3]'
Global Const $GWB_CMD_TEMPLATE_F = 'dword state;dword id;dword op;float argf[8];int result;dword done_frame;dword reserved[3]'
Global Const $GWB_BAGSLOT_HEAD_TEMPLATE = 'dword seq;dword counter;dword tick;dword signature;dword bag_count;dword reserved[3]'
