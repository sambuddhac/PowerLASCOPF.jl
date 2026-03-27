"""
Render generator_subproblem_flow.png and .pdf
Run from any directory: python3 gen_flow_render.py
"""
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch
import matplotlib.patheffects as pe

# ── Palette ───────────────────────────────────────────────────────────────────
BG        = "#0e1621"
ENTRY_C   = "#1a4a7a"      # dark blue  – entry / dispatch
THERMAL_C = "#6b2c0a"      # rust       – thermal
RENEW_C   = "#1a4d1a"      # dark green – renewable
HYDRO_C   = "#0a3d5c"      # teal       – hydro
STORAGE_C = "#4a1a5c"      # purple     – storage
BASE_C    = "#2c2c2c"      # dark grey  – gensolver_first_base
HELPER_C  = "#1c3c1c"      # muted green – helper calls
ARROW_C   = "#8ab4d4"
TEXT_C    = "#ddeeff"
TECH_COLORS = {
    "thermal":  THERMAL_C,
    "renewable": RENEW_C,
    "hydro":    HYDRO_C,
    "storage":  STORAGE_C,
}

# ── Layout constants ───────────────────────────────────────────────────────────
FIG_W, FIG_H = 26, 34
BOX_W   = 3.6      # standard box width
BOX_H   = 0.55     # standard box height
WIDE_W  = 5.2      # wide boxes (file headers)
HPAD    = 0.28     # horizontal padding inside subgraph
VPAD    = 0.28

fig, ax = plt.subplots(figsize=(FIG_W, FIG_H))
fig.patch.set_facecolor(BG)
ax.set_facecolor(BG)
ax.set_xlim(0, FIG_W)
ax.set_ylim(0, FIG_H)
ax.axis("off")


# ── Helper: draw a box and return its centre ──────────────────────────────────
def box(ax, cx, cy, w, h, label, color, fontsize=7.5, bold=False,
        italic=False, text_color=TEXT_C, radius=0.18):
    rect = FancyBboxPatch((cx - w/2, cy - h/2), w, h,
                          boxstyle=f"round,pad=0.06,rounding_size={radius}",
                          linewidth=0.8, edgecolor=ARROW_C,
                          facecolor=color, zorder=3)
    ax.add_patch(rect)
    weight = "bold" if bold else "normal"
    style  = "italic" if italic else "normal"
    ax.text(cx, cy, label, ha="center", va="center", color=text_color,
            fontsize=fontsize, fontweight=weight, fontstyle=style,
            zorder=4, wrap=False,
            multialignment="center")
    return (cx, cy)


def subgraph_bg(ax, x0, y0, x1, y1, label, color, alpha=0.18, fontsize=8.5):
    rect = FancyBboxPatch((x0, y0), x1-x0, y1-y0,
                          boxstyle="round,pad=0.04,rounding_size=0.25",
                          linewidth=1.2, edgecolor=color,
                          facecolor=color, alpha=alpha, zorder=1)
    ax.add_patch(rect)
    ax.text((x0+x1)/2, y1 - 0.22, label, ha="center", va="top",
            color=color, fontsize=fontsize, fontweight="bold",
            alpha=0.9, zorder=2)


def arrow(ax, x0, y0, x1, y1, color=ARROW_C, lw=1.2, label="", fs=6.5):
    ax.annotate("", xy=(x1, y1), xytext=(x0, y0),
                arrowprops=dict(arrowstyle="-|>", color=color,
                                lw=lw, mutation_scale=10),
                zorder=5)
    if label:
        mx, my = (x0+x1)/2, (y0+y1)/2
        ax.text(mx + 0.08, my, label, color=color, fontsize=fs,
                ha="left", va="center", zorder=6, style="italic")


# ═══════════════════════════════════════════════════════════════════════════════
# ROW 0 – Title
# ═══════════════════════════════════════════════════════════════════════════════
ax.text(FIG_W/2, FIG_H - 0.55,
        "Generator Subproblem Call Flow — PowerLASCOPF.jl",
        ha="center", va="center", color=TEXT_C,
        fontsize=13, fontweight="bold", zorder=6)

# ═══════════════════════════════════════════════════════════════════════════════
# ROW 1 – admm_app_solver.jl entry (top strip)
# ═══════════════════════════════════════════════════════════════════════════════
TOP = FIG_H - 1.5
subgraph_bg(ax, 0.4, TOP - 2.1, FIG_W - 0.4, TOP + 0.35,
            "admm_app_solver.jl", ENTRY_C, alpha=0.22)

BX, BY = FIG_W/2, TOP - 0.0
box(ax, BX, BY, WIDE_W, BOX_H,
    "gpower_angle_message!\n(gen::GeneralizedGenerator, …APP params…)",
    ENTRY_C, fontsize=7.5, bold=True)

BX2, BY2 = FIG_W/2, BY - 0.85
box(ax, BX2, BY2, WIDE_W, BOX_H,
    "update_admm_parameters!\n(gen.gen_solver, Dict{field → value})",
    ENTRY_C, fontsize=7.5)
arrow(ax, BX, BY - BOX_H/2, BX2, BY2 + BOX_H/2)

BX3, BY3 = FIG_W/2, BY2 - 0.85
box(ax, BX3, BY3, WIDE_W, BOX_H,
    "_dispatch_gen_subproblem!(gen)",
    ENTRY_C, fontsize=8, bold=True)
arrow(ax, BX2, BY2 - BOX_H/2, BX3, BY3 + BOX_H/2)

DISP_Y = BY3  # y of dispatch box

# ═══════════════════════════════════════════════════════════════════════════════
# ROW 2 – four technology "bridge" boxes (still in admm_app_solver.jl)
# ═══════════════════════════════════════════════════════════════════════════════
BRIDGE_Y = DISP_Y - 1.55
TECH_XS = [3.2, 9.3, 16.7, 22.8]   # cx for Thermal, Renewable, Hydro, Storage

TECH_INFO = [
    ("thermal",  "Thermal",  "solve_thermal_generator_subproblem!\n(gen::GeneralizedGenerator)",  THERMAL_C),
    ("renewable","Renewable","solve_renewable_generator_subproblem!\n(gen::GeneralizedGenerator)", RENEW_C),
    ("hydro",    "Hydro",    "solve_hydro_generator_subproblem!\n(gen::GeneralizedGenerator)",     HYDRO_C),
    ("storage",  "Storage",  "solve_storage_generator_subproblem!\n(gen::GeneralizedGenerator)",   STORAGE_C),
]
DISPATCH_LABELS = [
    "GeneralizedGenerator\n{<:PSY.ThermalGen}",
    "GeneralizedGenerator\n{<:PSY.RenewableGen}",
    "GeneralizedGenerator\n{<:PSY.HydroGen}",
    "GeneralizedGenerator\n{<:PSY.Storage}",
]

bridge_centres = []
for i, ((key, name, lbl, col), cx) in enumerate(zip(TECH_INFO, TECH_XS)):
    cy = BRIDGE_Y
    box(ax, cx, cy, BOX_W, BOX_H, lbl, col, fontsize=6.8)
    bridge_centres.append((cx, cy))
    # angled arrow from dispatch box
    arrow(ax, BX3, DISP_Y - BOX_H/2, cx, cy + BOX_H/2,
          color=col, label=DISPATCH_LABELS[i], fs=5.8)

# ═══════════════════════════════════════════════════════════════════════════════
# ROW 3–5 – per-technology component subgraphs
# ═══════════════════════════════════════════════════════════════════════════════
COMP_TOP = BRIDGE_Y - 1.0   # top of component subgraphs

# ── Column x-ranges ──
COL_RANGES = [
    (0.3,  6.4),   # Thermal
    (6.5, 12.6),   # Renewable
    (12.7, 18.8),  # Hydro
    (18.9, 25.0),  # Storage
]

# ── Thermal ───────────────────────────────────────────────────────────────────
COMP_H_ROWS = 6   # rows in Thermal (most complex)
SG_H = COMP_H_ROWS * 0.88 + 0.55
x0, x1 = COL_RANGES[0]
cx = (x0 + x1) / 2
subgraph_bg(ax, x0, COMP_TOP - SG_H, x1, COMP_TOP, "ExtendedThermalGenerator.jl",
            THERMAL_C, alpha=0.22)

rows_t = []
for r, (lbl, col, it) in enumerate([
    ("solve_thermal_generator_subproblem!\n(gen_solver::GenSolver, device::PSY.StaticInjection)",  THERMAL_C, False),
    ("solve_thermal_generator_subproblem!\n(gen::ExtendedThermalGenerator)",                        THERMAL_C, False),
    ("update_thermal_solver_from_generator!(gen)",                                                  HELPER_C,  True),
    ("build_and_solve_gensolver_for_gen!\n(gen.gen_solver, gen.generator)",                         THERMAL_C, False),
    ("extract_thermal_results_to_generator!(gen, results)",                                         HELPER_C,  True),
    ("update_thermal_performance!(gen)",                                                             HELPER_C,  True),
]):
    cy = COMP_TOP - 0.55 - r * 0.88
    box(ax, cx, cy, BOX_W + 0.1, BOX_H, lbl, col, fontsize=6.5, italic=it)
    rows_t.append((cx, cy))

# arrows inside thermal
for i in range(len(rows_t) - 1):
    arrow(ax, rows_t[i][0], rows_t[i][1] - BOX_H/2,
               rows_t[i+1][0], rows_t[i+1][1] + BOX_H/2, color=THERMAL_C)
# bridge → dispatch point
arrow(ax, bridge_centres[0][0], bridge_centres[0][1] - BOX_H/2,
          rows_t[0][0], rows_t[0][1] + BOX_H/2, color=THERMAL_C)

# ── Renewable ─────────────────────────────────────────────────────────────────
x0, x1 = COL_RANGES[1]
cx = (x0 + x1) / 2
RCOMP_H = 4 * 0.88 + 0.55
subgraph_bg(ax, x0, COMP_TOP - RCOMP_H, x1, COMP_TOP, "ExtendedRenewableGenerator.jl",
            RENEW_C, alpha=0.22)

rows_r = []
for r, (lbl, col, it) in enumerate([
    ("solve_renewable_generator_subproblem!\n(gen_solver::GenSolver, device::PSY.RenewableGen)", RENEW_C, False),
    ("solve_renewable_generator_subproblem!\n(gen::ExtendedRenewableGenerator)",                 RENEW_C, False),
    ("Sync GenFirstBaseInterval\n(Pg_prev, Pg_nu, Pg_nu_inner, Pg_next_nu)",                     HELPER_C, True),
    ("build_and_solve_gensolver_for_gen!\n(gen.gen_solver, gen.generator)",                      RENEW_C, False),
]):
    cy = COMP_TOP - 0.55 - r * 0.88
    box(ax, cx, cy, BOX_W + 0.1, BOX_H, lbl, col, fontsize=6.5, italic=it)
    rows_r.append((cx, cy))

for i in range(len(rows_r) - 1):
    arrow(ax, rows_r[i][0], rows_r[i][1] - BOX_H/2,
               rows_r[i+1][0], rows_r[i+1][1] + BOX_H/2, color=RENEW_C)
arrow(ax, bridge_centres[1][0], bridge_centres[1][1] - BOX_H/2,
          rows_r[0][0], rows_r[0][1] + BOX_H/2, color=RENEW_C)

# ── Hydro ─────────────────────────────────────────────────────────────────────
x0, x1 = COL_RANGES[2]
cx = (x0 + x1) / 2
HCOMP_H = 6 * 0.88 + 0.55
subgraph_bg(ax, x0, COMP_TOP - HCOMP_H, x1, COMP_TOP, "ExtendedHydroGenerator.jl",
            HYDRO_C, alpha=0.22)

rows_h = []
for r, (lbl, col, it) in enumerate([
    ("solve_hydro_generator_subproblem!\n(gen_solver::GenSolver, device::PSY.HydroGen)", HYDRO_C, False),
    ("solve_hydro_generator_subproblem!\n(gen::ExtendedHydroGenerator)",                 HYDRO_C, False),
    ("set_hydro_gen_data!(gen)",                                                          HELPER_C, True),
    ("Sync GenFirstBaseInterval\n(Pg_prev, Pg_nu, Pg_nu_inner, Pg_next_nu)",             HELPER_C, True),
    ("build_and_solve_gensolver_for_gen!\n(gen.gen_solver, gen.generator)",              HYDRO_C, False),
    ("update_hydro_performance!(gen)",                                                    HELPER_C, True),
]):
    cy = COMP_TOP - 0.55 - r * 0.88
    box(ax, cx, cy, BOX_W + 0.1, BOX_H, lbl, col, fontsize=6.5, italic=it)
    rows_h.append((cx, cy))

for i in range(len(rows_h) - 1):
    arrow(ax, rows_h[i][0], rows_h[i][1] - BOX_H/2,
               rows_h[i+1][0], rows_h[i+1][1] + BOX_H/2, color=HYDRO_C)
arrow(ax, bridge_centres[2][0], bridge_centres[2][1] - BOX_H/2,
          rows_h[0][0], rows_h[0][1] + BOX_H/2, color=HYDRO_C)

# ── Storage ───────────────────────────────────────────────────────────────────
x0, x1 = COL_RANGES[3]
cx = (x0 + x1) / 2
SCOMP_H = 5 * 0.88 + 0.55
subgraph_bg(ax, x0, COMP_TOP - SCOMP_H, x1, COMP_TOP, "ExtendedStorageGenerator.jl",
            STORAGE_C, alpha=0.22)

rows_s = []
for r, (lbl, col, it) in enumerate([
    ("solve_storage_generator_subproblem!\n(gen_solver::GenSolver, device::PSY.Storage)", STORAGE_C, False),
    ("solve_storage_generator_subproblem!\n(gen::ExtendedStorageGenerator)",               STORAGE_C, False),
    ("Sync GenFirstBaseInterval\n(Pg_prev, Pg_nu, Pg_nu_inner, Pg_next_nu)",              HELPER_C, True),
    ("build_and_solve_gensolver_for_gen!\n(gen.gen_solver, gen.generator)",               STORAGE_C, False),
    ("update_storage_performance!(gen, 1.0)",                                              HELPER_C, True),
]):
    cy = COMP_TOP - 0.55 - r * 0.88
    box(ax, cx, cy, BOX_W + 0.1, BOX_H, lbl, col, fontsize=6.5, italic=it)
    rows_s.append((cx, cy))

for i in range(len(rows_s) - 1):
    arrow(ax, rows_s[i][0], rows_s[i][1] - BOX_H/2,
               rows_s[i+1][0], rows_s[i+1][1] + BOX_H/2, color=STORAGE_C)
arrow(ax, bridge_centres[3][0], bridge_centres[3][1] - BOX_H/2,
          rows_s[0][0], rows_s[0][1] + BOX_H/2, color=STORAGE_C)

# ═══════════════════════════════════════════════════════════════════════════════
# ROW 6 – gensolver_first_base.jl
# ═══════════════════════════════════════════════════════════════════════════════
# Compute y bottom of the tallest component subgraph
BOTTOM_COMP = COMP_TOP - HCOMP_H   # hydro is tallest (6 rows)
BASE_TOP = BOTTOM_COMP - 0.55
BASE_BOT = BASE_TOP - 9.0
subgraph_bg(ax, 0.4, BASE_BOT, FIG_W - 0.4, BASE_TOP,
            "gensolver_first_base.jl", "#aaaaaa", alpha=0.18)

# Two entry overloads side by side
BF_THERMAL_X  = FIG_W * 0.28
BF_FALLBACK_X = FIG_W * 0.72
BF_Y = BASE_TOP - 0.55
box(ax, BF_THERMAL_X, BF_Y, WIDE_W - 0.3, BOX_H,
    "build_and_solve_gensolver_for_gen!\n(solver, device::PSY.ThermalGen)",
    BASE_C, fontsize=7)
box(ax, BF_FALLBACK_X, BF_Y, WIDE_W - 0.3, BOX_H,
    "build_and_solve_gensolver_for_gen!\n(solver, device::PSY.StaticInjection)",
    BASE_C, fontsize=7)

# Cross-subgraph arrows from component rows into BASE overloads
# Thermal → ThermalGen overload
arrow(ax, rows_t[3][0], rows_t[3][1] - BOX_H/2,
          BF_THERMAL_X,  BF_Y + BOX_H/2, color=THERMAL_C)
# Renewable → StaticInjection overload
arrow(ax, rows_r[3][0], rows_r[3][1] - BOX_H/2,
          BF_FALLBACK_X, BF_Y + BOX_H/2, color=RENEW_C)
# Hydro → StaticInjection overload
arrow(ax, rows_h[4][0], rows_h[4][1] - BOX_H/2,
          BF_FALLBACK_X, BF_Y + BOX_H/2, color=HYDRO_C)
# Storage → StaticInjection overload
arrow(ax, rows_s[3][0], rows_s[3][1] - BOX_H/2,
          BF_FALLBACK_X, BF_Y + BOX_H/2, color=STORAGE_C)

# ── Thermal subgraph: preallocated vs direct ──────────────────────────────────
PREALLOC_X = FIG_W * 0.18
DIRECT_T_X = FIG_W * 0.38
SEP_Y = BF_Y - 1.0

box(ax, PREALLOC_X, SEP_Y, BOX_W, BOX_H,
    "build_and_solve_gensolver_preallocated_for_gen!\n(use_preallocation=true)",
    BASE_C, fontsize=6.5)
box(ax, DIRECT_T_X, SEP_Y, BOX_W - 0.2, BOX_H,
    "Direct path — JuMP.Model\n(use_preallocation=false)",
    BASE_C, fontsize=6.5)

arrow(ax, BF_THERMAL_X, BF_Y - BOX_H/2, PREALLOC_X, SEP_Y + BOX_H/2,
      color=THERMAL_C, label="prealloc=true", fs=5.8)
arrow(ax, BF_THERMAL_X, BF_Y - BOX_H/2, DIRECT_T_X, SEP_Y + BOX_H/2,
      color=THERMAL_C, label="prealloc=false", fs=5.8)

# Preallocated helper chain
PREH = [
    "add_decision_variables_preallocated!",
    "add_constraints_preallocated!",
    "set_objective_preallocated!",
    "solve_gensolver_preallocated!",
]
prev_y = SEP_Y
for lbl in PREH:
    cy = prev_y - 0.9
    box(ax, PREALLOC_X, cy, BOX_W, BOX_H - 0.08, lbl, HELPER_C, fontsize=6.3, italic=True)
    arrow(ax, PREALLOC_X, prev_y - BOX_H/2, PREALLOC_X, cy + BOX_H/2, color="#558855")
    prev_y = cy

# Direct helper chain (thermal)
DIRH = [
    "add_decision_variables_direct!",
    "add_constraints_direct!",
    "set_objective_direct!",
    "solve_gensolver_direct!",
]
prev_y = SEP_Y
for lbl in DIRH:
    cy = prev_y - 0.9
    box(ax, DIRECT_T_X, cy, BOX_W - 0.2, BOX_H - 0.08, lbl, HELPER_C, fontsize=6.3, italic=True)
    arrow(ax, DIRECT_T_X, prev_y - BOX_H/2, DIRECT_T_X, cy + BOX_H/2, color="#558855")
    prev_y = cy

# ── Fallback (non-thermal) direct path ───────────────────────────────────────
DIRECT_F_X = FIG_W * 0.72
prev_y = BF_Y
for lbl in DIRH:
    cy = prev_y - 0.9
    box(ax, DIRECT_F_X, cy, BOX_W + 0.3, BOX_H - 0.08, lbl, HELPER_C, fontsize=6.3, italic=True)
    arrow(ax, DIRECT_F_X, prev_y - BOX_H/2, DIRECT_F_X, cy + BOX_H/2, color="#558855")
    prev_y = cy

# ═══════════════════════════════════════════════════════════════════════════════
# Legend
# ═══════════════════════════════════════════════════════════════════════════════
legend_items = [
    (ENTRY_C,    "admm_app_solver.jl — entry / dispatch"),
    (THERMAL_C,  "Thermal  (ExtendedThermalGenerator)"),
    (RENEW_C,    "Renewable (ExtendedRenewableGenerator)"),
    (HYDRO_C,    "Hydro    (ExtendedHydroGenerator)"),
    (STORAGE_C,  "Storage  (ExtendedStorageGenerator)"),
    (BASE_C,     "gensolver_first_base.jl — solver"),
    (HELPER_C,   "Helper / post-processing calls"),
]
for i, (col, label) in enumerate(legend_items):
    lx, ly = 0.6, 2.0 - i * 0.36
    patch = mpatches.Patch(color=col, label=label, linewidth=0.5,
                           edgecolor=ARROW_C)
    ax.add_patch(FancyBboxPatch((lx, ly - 0.12), 0.5, 0.24,
                                boxstyle="round,pad=0.03",
                                facecolor=col, edgecolor=ARROW_C, lw=0.6, zorder=3))
    ax.text(lx + 0.65, ly, label, color=TEXT_C, fontsize=7, va="center", zorder=4)

ax.text(0.6, 2.45, "Legend", color=TEXT_C, fontsize=8, fontweight="bold")

# ── Save ──────────────────────────────────────────────────────────────────────
import os
OUT_DIR = os.path.dirname(os.path.abspath(__file__))

png_path = os.path.join(OUT_DIR, "generator_subproblem_flow.png")
pdf_path = os.path.join(OUT_DIR, "generator_subproblem_flow.pdf")

fig.savefig(png_path, dpi=180, bbox_inches="tight", facecolor=BG)
fig.savefig(pdf_path, bbox_inches="tight", facecolor=BG)
print(f"Saved:\n  {png_path}\n  {pdf_path}")
