"""
PowerLASCOPF ADMM-APP Solver Visualization
==========================================
Visualizes the ADMM decomposition and APP proximal method for SCOPF

Usage:
    manim -pql powerlascopf_admm.py ADMMOverview
    manim -pql powerlascopf_admm.py APPMethod
    manim -pql powerlascopf_admm.py DistributedOptimization
"""

from manim import *
import numpy as np


class ADMMOverview(Scene):
    """Overview of ADMM for SCOPF"""
    
    def construct(self):
        title = Text("ADMM for Security-Constrained OPF", font_size=40, color=ORANGE)
        title.to_edge(UP)
        self.play(Write(title))
        
        subtitle = Text(
            "Alternating Direction Method of Multipliers",
            font_size=20,
            color=GREY
        )
        subtitle.next_to(title, DOWN)
        self.play(FadeIn(subtitle))
        self.wait()
        
        # Show problem formulation
        self.show_problem_formulation()
        
        # Show ADMM decomposition
        self.show_admm_decomposition()
        
        self.wait(3)
    
    def show_problem_formulation(self):
        """Show the SCOPF problem"""
        problem = VGroup(
            Text("Original SCOPF Problem:", font_size=24, color=YELLOW),
            MathTex(r"\min_{x,y} \quad f(x) + g(y)", font_size=28),
            MathTex(r"\text{s.t.} \quad Ax + By = c", font_size=24),
            MathTex(r"\text{Power flow, Security constraints}", font_size=20, color=GREY)
        ).arrange(DOWN, buff=0.3)
        problem.shift(UP * 1.5)
        
        for line in problem:
            self.play(Write(line), run_time=0.8)
            self.wait(0.3)
        
        self.wait(2)
        self.play(FadeOut(problem))
    
    def show_admm_decomposition(self):
        """Show how ADMM decomposes the problem"""
        # Original problem
        original = self.create_problem_box(
            "Centralized SCOPF",
            "Large-scale\nCoupled problem",
            RED,
            width=4,
            height=2
        )
        original.shift(LEFT * 4 + UP * 0.5)
        
        self.play(FadeIn(original))
        self.wait()
        
        # Decomposition arrow
        arrow = Arrow(
            original.get_right(),
            original.get_right() + RIGHT * 2,
            buff=0.1,
            color=YELLOW,
            stroke_width=5
        )
        arrow_label = Text("ADMM\nDecomposition", font_size=16, color=YELLOW)
        arrow_label.next_to(arrow, UP)
        
        self.play(GrowArrow(arrow), Write(arrow_label))
        self.wait()
        
        # Decomposed subproblems
        subproblems = VGroup(
            self.create_problem_box("Subproblem 1", "Generator\nDispatch", BLUE, 2.5, 1.5),
            self.create_problem_box("Subproblem 2", "Transmission\nLimits", GREEN, 2.5, 1.5),
            self.create_problem_box("Subproblem 3", "Security\nConstraints", PURPLE, 2.5, 1.5)
        ).arrange(DOWN, buff=0.4)
        subproblems.shift(RIGHT * 3)
        
        for sub in subproblems:
            self.play(FadeIn(sub, shift=LEFT), run_time=0.6)
            self.wait(0.2)
        
        # Show coordination
        coord_arrows = VGroup(*[
            CurvedArrow(
                sub.get_left(),
                subproblems[(i + 1) % 3].get_left(),
                angle=-TAU/6,
                color=ORANGE,
                stroke_width=2
            )
            for i, sub in enumerate(subproblems)
        ])
        
        coord_label = Text("Coordination\nvia dual variables", font_size=14, color=ORANGE)
        coord_label.next_to(subproblems, RIGHT, buff=0.5)
        
        self.play(
            *[Create(arrow) for arrow in coord_arrows],
            Write(coord_label)
        )
        
        self.wait(2)
    
    def create_problem_box(self, title, description, color, width=3, height=2):
        """Create a problem box"""
        box = RoundedRectangle(
            width=width,
            height=height,
            fill_color=color,
            fill_opacity=0.3,
            stroke_color=color,
            stroke_width=3,
            corner_radius=0.1
        )
        
        title_text = Text(title, font_size=18, color=color, weight=BOLD)
        title_text.move_to(box.get_top() + DOWN * 0.4)
        
        desc_text = Text(description, font_size=14, color=WHITE)
        desc_text.move_to(box.get_center() + DOWN * 0.2)
        
        return VGroup(box, title_text, desc_text)


class ADMMAlgorithm(Scene):
    """Show the ADMM algorithm steps"""
    
    def construct(self):
        title = Text("ADMM Algorithm", font_size=44, color=BLUE)
        title.to_edge(UP)
        self.play(Write(title))
        self.wait()
        
        # Show augmented Lagrangian
        aug_lag = VGroup(
            Text("Augmented Lagrangian:", font_size=24, color=YELLOW),
            MathTex(
                r"L_\rho(x, y, \lambda) = f(x) + g(y) + \lambda^T(Ax + By - c) + \frac{\rho}{2}\|Ax + By - c\|^2",
                font_size=18
            )
        ).arrange(DOWN, buff=0.3)
        aug_lag.shift(UP * 1.8)
        
        self.play(Write(aug_lag))
        self.wait()
        
        # ADMM steps
        steps = VGroup(
            self.create_algorithm_step(
                "1",
                "x-update (primal)",
                r"x^{k+1} = \arg\min_x L_\rho(x, y^k, \lambda^k)",
                BLUE
            ),
            self.create_algorithm_step(
                "2",
                "y-update (primal)",
                r"y^{k+1} = \arg\min_y L_\rho(x^{k+1}, y, \lambda^k)",
                GREEN
            ),
            self.create_algorithm_step(
                "3",
                "λ-update (dual)",
                r"\lambda^{k+1} = \lambda^k + \rho(Ax^{k+1} + By^{k+1} - c)",
                PURPLE
            )
        ).arrange(DOWN, buff=0.5)
        steps.scale(0.8).shift(DOWN * 0.5)
        
        for step in steps:
            self.play(FadeIn(step, shift=UP), run_time=0.8)
            self.wait(0.4)
        
        # Show iteration
        iteration_label = Text("Repeat until convergence", font_size=20, color=ORANGE, slant=ITALIC)
        iteration_label.to_edge(DOWN)
        self.play(Write(iteration_label))
        
        self.wait(3)
    
    def create_algorithm_step(self, num, name, formula, color):
        """Create an algorithm step"""
        circle = Circle(radius=0.3, color=color, fill_opacity=0.8)
        num_text = Text(num, font_size=20, color=WHITE, weight=BOLD)
        num_text.move_to(circle.get_center())
        
        name_text = Text(name, font_size=18, color=color)
        formula_text = MathTex(formula, font_size=20)
        
        content = VGroup(name_text, formula_text).arrange(DOWN, buff=0.15)
        
        step = VGroup(VGroup(circle, num_text), content)
        step.arrange(RIGHT, buff=0.5)
        
        box = SurroundingRectangle(step, color=color, buff=0.2, stroke_width=2, corner_radius=0.1)
        
        return VGroup(box, step)


class APPMethod(Scene):
    """Show the APP (Asynchronous Proximal Point) method"""
    
    def construct(self):
        title = Text("APP: Asynchronous Proximal Point Method", font_size=38, color=PURPLE)
        title.to_edge(UP)
        self.play(Write(title))
        self.wait()
        
        # Show why APP
        why_app = VGroup(
            Text("Why APP?", font_size=28, color=YELLOW, weight=BOLD),
            Text("", font_size=14),
            Text("✓ Handles asynchronous updates", font_size=18, color=GREEN),
            Text("✓ Better for distributed systems", font_size=18, color=GREEN),
            Text("✓ Robust to communication delays", font_size=18, color=GREEN),
            Text("✓ Guaranteed convergence", font_size=18, color=GREEN)
        ).arrange(DOWN, aligned_edge=LEFT, buff=0.2)
        why_app.shift(LEFT * 3 + DOWN * 0.5)
        
        for item in why_app:
            self.play(FadeIn(item, shift=RIGHT), run_time=0.5)
            self.wait(0.2)
        
        # Show APP formula
        app_formula = VGroup(
            Text("APP Update:", font_size=24, color=PURPLE),
            MathTex(
                r"x^{k+1} = \text{prox}_{\rho f}(x^k - \rho \nabla g(x^k))",
                font_size=26
            )
        ).arrange(DOWN, buff=0.3)
        app_formula.shift(RIGHT * 3 + DOWN * 0.5)
        
        self.play(Write(app_formula))
        
        self.wait(3)


class DistributedOptimization(Scene):
    """Visualize distributed optimization with ADMM-APP"""
    
    def construct(self):
        title = Text("Distributed SCOPF with ADMM-APP", font_size=40, color=BLUE)
        title.to_edge(UP)
        self.play(Write(title))
        self.wait()
        
        # Create network of agents
        self.create_agent_network()
        
        # Animate iterations
        self.animate_iterations()
        
        self.wait(3)
    
    def create_agent_network(self):
        """Create a network of optimization agents"""
        # Central coordinator
        coordinator = Circle(radius=0.5, color=YELLOW, fill_opacity=0.7)
        coord_label = Text("Coordinator", font_size=14, color=BLACK, weight=BOLD)
        coord_label.move_to(coordinator.get_center())
        self.coordinator_group = VGroup(coordinator, coord_label)
        
        # Agents around coordinator
        num_agents = 6
        agents = VGroup()
        for i in range(num_agents):
            angle = i * TAU / num_agents
            pos = np.array([np.cos(angle), np.sin(angle), 0]) * 3
            
            agent = Circle(radius=0.4, color=BLUE, fill_opacity=0.6)
            agent.move_to(pos)
            label = Text(f"Agent {i+1}", font_size=12, color=WHITE)
            label.move_to(agent.get_center())
            
            agents.add(VGroup(agent, label))
        
        self.agents = agents
        
        # Connections
        self.connections = VGroup(*[
            Line(
                coordinator.get_center(),
                agent[0].get_center(),
                stroke_width=2,
                color=GREY
            )
            for agent in agents
        ])
        
        # Animate creation
        self.play(FadeIn(self.coordinator_group))
        self.play(*[FadeIn(agent) for agent in agents])
        self.play(*[Create(conn) for conn in self.connections])
        self.wait()
    
    def animate_iterations(self):
        """Animate ADMM iterations"""
        for iteration in range(3):
            # Agents solve local problems
            for agent in self.agents:
                self.play(
                    agent[0].animate.set_fill(color=GREEN, opacity=0.9),
                    run_time=0.3
                )
            self.wait(0.2)
            
            # Send to coordinator
            for conn in self.connections:
                self.play(
                    conn.animate.set_stroke(color=YELLOW, width=4),
                    run_time=0.2
                )
                self.play(
                    conn.animate.set_stroke(color=GREY, width=2),
                    run_time=0.1
                )
            
            # Reset colors
            for agent in self.agents:
                self.play(
                    agent[0].animate.set_fill(color=BLUE, opacity=0.6),
                    run_time=0.2
                )
            self.play(
                self.coordinator_group[0].animate.set_fill(color=YELLOW, opacity=0.7),
                run_time=0.2
            )
            
            # Show iteration counter
            iteration_text = Text(f"Iteration {iteration + 1}", font_size=20, color=GREEN)
            iteration_text.to_edge(DOWN)
            if iteration > 0:
                self.play(Transform(self.iteration_label, iteration_text), run_time=0.3)
            else:
                self.iteration_label = iteration_text
                self.play(FadeIn(self.iteration_label))
            
            self.wait(0.5)


class ConvergenceVisualization(Scene):
    """Visualize ADMM convergence"""
    
    def construct(self):
        title = Text("ADMM Convergence", font_size=44, color=GREEN)
        title.to_edge(UP)
        self.play(Write(title))
        self.wait()
        
        # Create convergence plot
        axes = Axes(
            x_range=[0, 50, 10],
            y_range=[0, 10, 2],
            x_length=8,
            y_length=4,
            axis_config={"include_tip": True},
            x_axis_config={"numbers_to_include": [0, 10, 20, 30, 40, 50]},
            y_axis_config={"numbers_to_include": [0, 2, 4, 6, 8, 10]}
        )
        axes.shift(DOWN * 0.5)
        
        # Labels
        x_label = Text("Iteration", font_size=20)
        x_label.next_to(axes.x_axis, DOWN)
        
        y_label = Text("Residual", font_size=20)
        y_label.next_to(axes.y_axis, LEFT).rotate(90 * DEGREES)
        
        self.play(Create(axes), Write(x_label), Write(y_label))
        
        # Primal residual
        primal_curve = axes.plot(
            lambda x: 8 * np.exp(-x/10) + 0.5,
            x_range=[0, 50],
            color=BLUE
        )
        primal_label = Text("Primal Residual", font_size=16, color=BLUE)
        primal_label.next_to(axes, RIGHT, buff=0.5).shift(UP * 1.5)
        
        # Dual residual
        dual_curve = axes.plot(
            lambda x: 6 * np.exp(-x/12) + 0.3,
            x_range=[0, 50],
            color=RED
        )
        dual_label = Text("Dual Residual", font_size=16, color=RED)
        dual_label.next_to(primal_label, DOWN, buff=0.2)
        
        # Convergence threshold
        threshold = DashedLine(
            axes.c2p(0, 1),
            axes.c2p(50, 1),
            color=YELLOW,
            stroke_width=2
        )
        threshold_label = Text("Convergence\nThreshold", font_size=14, color=YELLOW)
        threshold_label.next_to(threshold, RIGHT, buff=0.1)
        
        # Animate curves
        self.play(
            Create(primal_curve),
            Write(primal_label),
            run_time=2
        )
        self.wait(0.5)
        
        self.play(
            Create(dual_curve),
            Write(dual_label),
            run_time=2
        )
        self.wait(0.5)
        
        self.play(
            Create(threshold),
            Write(threshold_label)
        )
        
        # Highlight convergence point
        convergence_point = Dot(
            axes.c2p(35, 1),
            color=GREEN,
            radius=0.1
        )
        convergence_text = Text("Converged!", font_size=18, color=GREEN, weight=BOLD)
        convergence_text.next_to(convergence_point, UP, buff=0.3)
        
        self.play(
            FadeIn(convergence_point, scale=2),
            Write(convergence_text)
        )
        
        self.wait(3)


class ADMMvsCentralized(Scene):
    """Compare ADMM with centralized optimization"""
    
    def construct(self):
        title = Text("ADMM vs Centralized Optimization", font_size=38)
        title.to_edge(UP)
        self.play(Write(title))
        self.wait()
        
        # Comparison table
        comparison = VGroup(
            self.create_comparison_row("", "Centralized", "ADMM", YELLOW, header=True),
            self.create_comparison_row("Scalability", "Limited", "Excellent", GREEN),
            self.create_comparison_row("Computation", "Single solver", "Parallel", BLUE),
            self.create_comparison_row("Memory", "O(n²)", "O(n)", PURPLE),
            self.create_comparison_row("Privacy", "Full sharing", "Local data", ORANGE),
            self.create_comparison_row("Robustness", "Single point", "Distributed", RED),
            self.create_comparison_row("Speed", "Fast (small)", "Fast (large)", GREEN)
        ).arrange(DOWN, buff=0.15)
        comparison.scale(0.75).shift(DOWN * 0.5)
        
        for row in comparison:
            self.play(FadeIn(row, shift=UP), run_time=0.5)
            self.wait(0.2)
        
        # Conclusion
        conclusion = Text(
            "ADMM is ideal for large-scale power system optimization!",
            font_size=18,
            color=GREEN,
            weight=BOLD
        )
        conclusion.to_edge(DOWN)
        self.play(Write(conclusion))
        
        self.wait(3)
    
    def create_comparison_row(self, category, centralized, admm, color, header=False):
        """Create a comparison table row"""
        if header:
            cat_text = Text(category, font_size=18, color=color, weight=BOLD)
            cent_text = Text(centralized, font_size=18, color=color, weight=BOLD)
            admm_text = Text(admm, font_size=18, color=color, weight=BOLD)
        else:
            cat_text = Text(category, font_size=16, color=WHITE)
            cent_text = Text(centralized, font_size=15, color=GREY)
            admm_text = Text(admm, font_size=15, color=color)
        
        # Fixed width boxes
        cat_box = Rectangle(width=2.5, height=0.6, stroke_color=GREY, stroke_width=1)
        cent_box = Rectangle(width=2.5, height=0.6, stroke_color=GREY, stroke_width=1)
        admm_box = Rectangle(width=2.5, height=0.6, stroke_color=GREY, stroke_width=1)
        
        cat_text.move_to(cat_box.get_center())
        cent_text.move_to(cent_box.get_center())
        admm_text.move_to(admm_box.get_center())
        
        row = VGroup(
            VGroup(cat_box, cat_text),
            VGroup(cent_box, cent_text),
            VGroup(admm_box, admm_text)
        ).arrange(RIGHT, buff=0.1)
        
        return row


class RealWorldApplication(Scene):
    """Show real-world application scenario"""
    
    def construct(self):
        title = Text("ADMM-APP in Real Power Grids", font_size=40, color=ORANGE)
        title.to_edge(UP)
        self.play(Write(title))
        self.wait()
        
        # Show power grid schematic
        self.show_power_grid()
        
        # Show problem decomposition
        self.show_decomposition()
        
        self.wait(3)
    
    def show_power_grid(self):
        """Show simplified power grid"""
        # Generators
        generators = VGroup(*[
            self.create_component("G", GREEN, 0.4)
            for _ in range(3)
        ]).arrange(DOWN, buff=1)
        generators.shift(LEFT * 4)
        
        gen_label = Text("Generators", font_size=18, color=GREEN)
        gen_label.next_to(generators, UP)
        
        # Transmission lines
        lines = VGroup(*[
            Line(
                generators[i].get_right(),
                generators[i].get_right() + RIGHT * 3,
                stroke_width=3,
                color=BLUE
            )
            for i in range(3)
        ])
        
        # Loads
        loads = VGroup(*[
            self.create_component("L", RED, 0.4)
            for _ in range(3)
        ]).arrange(DOWN, buff=1)
        loads.shift(RIGHT * 1)
        
        load_label = Text("Loads", font_size=18, color=RED)
        load_label.next_to(loads, UP)
        
        # Connect
        for i in range(3):
            loads[i].move_to(lines[i].get_right())
        
        grid = VGroup(generators, lines, loads)
        
        self.play(
            FadeIn(generators),
            Write(gen_label)
        )
        self.wait(0.5)
        self.play(*[Create(line) for line in lines])
        self.wait(0.5)
        self.play(
            FadeIn(loads),
            Write(load_label)
        )
        
        self.wait(2)
        self.play(FadeOut(VGroup(grid, gen_label, load_label)))
    
    def show_decomposition(self):
        """Show how the problem is decomposed"""
        decomp_text = VGroup(
            Text("Problem Decomposition:", font_size=26, color=YELLOW, weight=BOLD),
            Text("", font_size=14),
            Text("1. Each generator: local cost minimization", font_size=18, color=GREEN),
            Text("2. Each line: flow limit constraints", font_size=18, color=BLUE),
            Text("3. Security: contingency scenarios", font_size=18, color=PURPLE),
            Text("4. Coordinator: enforce coupling constraints", font_size=18, color=ORANGE),
            Text("", font_size=14),
            Text("All solved in parallel with ADMM-APP!", font_size=20, color=GREEN, weight=BOLD)
        ).arrange(DOWN, aligned_edge=LEFT, buff=0.2)
        decomp_text.shift(DOWN * 0.5)
        
        for line in decomp_text:
            self.play(FadeIn(line, shift=UP), run_time=0.5)
            self.wait(0.2)
        
        self.wait()
    
    def create_component(self, label, color, radius):
        """Create a grid component"""
        circle = Circle(radius=radius, color=color, fill_opacity=0.7)
        text = Text(label, font_size=16, color=WHITE, weight=BOLD)
        text.move_to(circle.get_center())
        return VGroup(circle, text)


class PerformanceMetrics(Scene):
    """Show performance metrics of ADMM-APP"""
    
    def construct(self):
        title = Text("ADMM-APP Performance", font_size=44, color=BLUE)
        title.to_edge(UP)
        self.play(Write(title))
        self.wait()
        
        # Create metrics
        metrics = VGroup(
            self.create_metric_card(
                "Speedup",
                "10-100×",
                "vs centralized for large systems",
                GREEN
            ),
            self.create_metric_card(
                "Scalability",
                "1000+ buses",
                "Handles very large grids",
                BLUE
            ),
            self.create_metric_card(
                "Convergence",
                "<1 minute",
                "Typical convergence time",
                PURPLE
            ),
            self.create_metric_card(
                "Accuracy",
                "~0.01%",
                "Near-optimal solutions",
                ORANGE
            )
        ).arrange_in_grid(rows=2, cols=2, buff=0.8)
        metrics.scale(0.8).shift(DOWN * 0.5)
        
        for metric in metrics:
            self.play(FadeIn(metric, scale=0.8), run_time=0.6)
            self.wait(0.3)
        
        self.wait(3)
    
    def create_metric_card(self, title, value, description, color):
        """Create a metric card"""
        card = Rectangle(
            width=3.5,
            height=2,
            fill_color=color,
            fill_opacity=0.2,
            stroke_color=color,
            stroke_width=3,
            corner_radius=0.15
        )
        
        title_text = Text(title, font_size=18, color=color, weight=BOLD)
        title_text.move_to(card.get_top() + DOWN * 0.4)
        
        value_text = Text(value, font_size=32, color=WHITE, weight=BOLD)
        value_text.move_to(card.get_center())
        
        desc_text = Text(description, font_size=12, color=GREY)
        desc_text.move_to(card.get_bottom() + UP * 0.4)
        
        return VGroup(card, title_text, value_text, desc_text)


if __name__ == "__main__":
    print("PowerLASCOPF ADMM-APP Solver Animations")
    print("\nAvailable scenes:")
    print("  1. ADMMOverview - Overview of ADMM decomposition")
    print("  2. ADMMAlgorithm - ADMM algorithm steps")
    print("  3. APPMethod - Asynchronous Proximal Point method")
    print("  4. DistributedOptimization - Distributed optimization visualization")
    print("  5. ConvergenceVisualization - ADMM convergence curves")
    print("  6. ADMMvsCentralized - Comparison with centralized methods")
    print("  7. RealWorldApplication - Real power grid application")
    print("  8. PerformanceMetrics - Performance characteristics")
    print("\nUsage:")
    print("  manim -pql powerlascopf_admm.py ADMMOverview")
    print("  manim -pqh powerlascopf_admm.py DistributedOptimization")

            
    # Coordinator updates
    self.play(
        self.coordinator_group[0].animate.set_fill(color=RED, opacity=0.9),
        run_time=0.3
    )
    self.wait(0.2)
            
    # Broadcast back
    for conn in self.connections:
        self.play(
            conn.animate.set_stroke(color=ORANGE, width=4),
            run_time=0.2
        )
        self.play(
            conn.animate.set_stroke(color=GREY, width=2),
            run_time=0.1
        )