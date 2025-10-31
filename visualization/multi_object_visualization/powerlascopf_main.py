"""
PowerLASCOPF Actor-Critic Workflow - Main Animation
====================================================
Complete workflow visualization for PowerLASCOPF with POMDP-based RL and ADMM-APP SCOPF solver

File structure:
- powerlascopf_main.py (this file): Main workflow and system overview
- powerlascopf_actor_critic.py: Detailed actor-critic architecture
- powerlascopf_pomdp.py: POMDP interface and belief updates
- powerlascopf_admm.py: ADMM-APP solver visualization
- powerlascopf_training.py: Training loop and learning dynamics

Usage:
    manim -pql powerlascopf_main.py SystemOverview
    manim -pqh powerlascopf_main.py CompleteWorkflow
"""

from manim import *
import numpy as np


class SystemOverview(Scene):
    """High-level overview of the PowerLASCOPF system"""
    
    def construct(self):
        # Title
        title = Text("PowerLASCOPF System Architecture", font_size=48, color=BLUE)
        title.to_edge(UP)
        self.play(Write(title))
        self.wait()
        
        # Subtitle
        subtitle = Text(
            "POMDP-based Reinforcement Learning for Security-Constrained Optimal Power Flow",
            font_size=20,
            color=GREY
        )
        subtitle.next_to(title, DOWN)
        self.play(FadeIn(subtitle))
        self.wait()
        
        # Create three main components
        components = self.create_system_components()
        components.scale(0.8).shift(DOWN * 0.5)
        
        # Animate component appearance
        for i, comp in enumerate(components):
            self.play(FadeIn(comp), run_time=1)
            self.wait(0.5)
        
        # Show data flow
        self.show_data_flow(components)
        
        # Add component labels
        self.add_component_details(components)
        
        self.wait(3)
    
    def create_system_components(self):
        """Create the three main system components"""
        
        # 1. POMDP/RL Layer
        pomdp_box = self.create_component_box(
            "POMDP/RL Layer",
            [
                "State: Power grid status",
                "Actions: Control decisions",
                "Observations: Partial info",
                "Belief: Probability dist."
            ],
            GREEN,
            width=4.5,
            height=3
        )
        
        # 2. Actor-Critic Networks
        ac_box = self.create_component_box(
            "Actor-Critic Networks",
            [
                "Actor: Policy π(a|s)",
                "Critic: Value V(s)",
                "Flux.jl / TF / PyTorch",
                "Training: TD Learning"
            ],
            BLUE,
            width=4.5,
            height=3
        )
        
        # 3. ADMM-APP Solver
        solver_box = self.create_component_box(
            "ADMM-APP SCOPF Solver",
            [
                "ADMM: Distributed opt",
                "APP: Prox method",
                "Security constraints",
                "Power flow equations"
            ],
            ORANGE,
            width=4.5,
            height=3
        )
        
        # Arrange horizontally
        components = VGroup(pomdp_box, ac_box, solver_box)
        components.arrange(RIGHT, buff=0.8)
        
        return components
    
    def create_component_box(self, title, items, color, width=4, height=2.5):
        """Create a styled component box"""
        # Main box
        box = RoundedRectangle(
            width=width,
            height=height,
            fill_color=color,
            fill_opacity=0.2,
            stroke_color=color,
            stroke_width=3,
            corner_radius=0.15
        )
        
        # Title
        title_text = Text(title, font_size=22, color=color, weight=BOLD)
        title_text.next_to(box.get_top(), DOWN, buff=0.2)
        
        # Items
        item_texts = VGroup(*[
            Text(f"• {item}", font_size=14, color=GREY_A)
            for item in items
        ]).arrange(DOWN, aligned_edge=LEFT, buff=0.15)
        item_texts.next_to(title_text, DOWN, buff=0.3)
        item_texts.shift(RIGHT * 0.2)
        
        return VGroup(box, title_text, item_texts)
    
    def show_data_flow(self, components):
        """Show data flow between components"""
        pomdp, actor_critic, solver = components
        
        # Arrow 1: POMDP -> Actor-Critic (State/Observation)
        arrow1 = Arrow(
            pomdp.get_right(),
            actor_critic.get_left(),
            buff=0.1,
            color=YELLOW,
            stroke_width=4
        )
        label1 = Text("State s_t", font_size=16, color=YELLOW)
        label1.next_to(arrow1, UP, buff=0.1)
        
        self.play(GrowArrow(arrow1), FadeIn(label1))
        self.wait(0.5)
        
        # Arrow 2: Actor-Critic -> Solver (Action)
        arrow2 = Arrow(
            actor_critic.get_right(),
            solver.get_left(),
            buff=0.1,
            color=YELLOW,
            stroke_width=4
        )
        label2 = Text("Action a_t", font_size=16, color=YELLOW)
        label2.next_to(arrow2, UP, buff=0.1)
        
        self.play(GrowArrow(arrow2), FadeIn(label2))
        self.wait(0.5)
        
        # Arrow 3: Solver -> POMDP (Reward, Next State)
        arrow3 = CurvedArrow(
            solver.get_bottom() + DOWN * 0.3,
            pomdp.get_bottom() + DOWN * 0.3,
            angle=-TAU/4,
            color=GREEN,
            stroke_width=4
        )
        label3 = Text("Reward r_t, s_{t+1}", font_size=16, color=GREEN)
        label3.next_to(arrow3, DOWN, buff=0.2)
        
        self.play(Create(arrow3), FadeIn(label3))
        self.wait()
    
    def add_component_details(self, components):
        """Add additional details about each component"""
        
        # Framework labels
        frameworks = VGroup(
            Text("POMDPs.jl", font_size=14, color=GREEN_A),
            Text("Flux.jl/TF/PyTorch", font_size=14, color=BLUE_A),
            Text("PowerModels.jl", font_size=14, color="#FFA500")
        )
        
        for i, (comp, fw) in enumerate(zip(components, frameworks)):
            fw.next_to(comp, DOWN, buff=0.3)
            self.play(FadeIn(fw), run_time=0.5)
        
        self.wait()


class CompleteWorkflow(Scene):
    """Detailed step-by-step workflow animation"""
    
    def construct(self):
        # Title
        title = Text("PowerLASCOPF Complete Workflow", font_size=42, color=BLUE)
        title.to_edge(UP)
        self.play(Write(title))
        self.wait()
        
        # Show workflow stages
        self.show_initialization()
        self.wait(1)
        self.clear()
        
        self.show_episode_loop()
        self.wait(1)
        self.clear()
        
        self.show_training_update()
        self.wait(2)
    
    def show_initialization(self):
        """Show system initialization"""
        title = Text("Stage 1: Initialization", font_size=36, color=GREEN)
        title.to_edge(UP)
        self.play(Write(title))
        
        steps = VGroup(
            self.create_step_box("1", "Load Power System", "PowerSystems.jl", GREEN),
            self.create_step_box("2", "Initialize POMDP", "Define S, A, O, R, T", BLUE),
            self.create_step_box("3", "Create Networks", "Actor & Critic NNs", PURPLE),
            self.create_step_box("4", "Setup ADMM Solver", "Distributed SCOPF", ORANGE)
        ).arrange(DOWN, buff=0.4)
        steps.scale(0.7).shift(DOWN * 0.5)
        
        for step in steps:
            self.play(FadeIn(step, shift=UP), run_time=0.8)
            self.wait(0.3)
        
        self.wait()
    
    def show_episode_loop(self):
        """Show the main episode loop"""
        title = Text("Stage 2: Episode Loop", font_size=36, color=BLUE)
        title.to_edge(UP)
        self.play(Write(title))
        
        # Create flowchart
        flowchart = self.create_episode_flowchart()
        flowchart.scale(0.7).shift(DOWN * 0.5)
        
        # Animate flowchart
        for element in flowchart:
            self.play(FadeIn(element), run_time=0.6)
            self.wait(0.2)
        
        # Animate data flow through flowchart
        self.animate_flowchart_execution(flowchart)
        
        self.wait()
    
    def create_episode_flowchart(self):
        """Create episode loop flowchart"""
        # Nodes
        observe = self.create_flow_node("Observe State", GREEN)
        actor = self.create_flow_node("Actor: Select Action", BLUE)
        solver = self.create_flow_node("ADMM-APP Solver", ORANGE)
        reward = self.create_flow_node("Compute Reward", YELLOW)
        update_belief = self.create_flow_node("Update Belief", PURPLE)
        critic = self.create_flow_node("Critic: Evaluate", RED)
        
        # Arrange vertically with spacing
        nodes = VGroup(observe, actor, solver, reward, update_belief, critic)
        nodes.arrange(DOWN, buff=0.6)
        
        # Add arrows
        arrows = VGroup()
        for i in range(len(nodes) - 1):
            arrow = Arrow(
                nodes[i].get_bottom(),
                nodes[i+1].get_top(),
                buff=0.1,
                stroke_width=3,
                color=WHITE
            )
            arrows.add(arrow)
        
        # Loop back arrow
        loop_arrow = CurvedArrow(
            critic.get_left() + LEFT * 0.2,
            observe.get_left() + LEFT * 0.2,
            angle=-TAU/3,
            color=GREEN,
            stroke_width=3
        )
        arrows.add(loop_arrow)
        
        loop_label = Text("Next timestep", font_size=12, color=GREEN)
        loop_label.next_to(loop_arrow, LEFT, buff=0.1)
        
        return VGroup(nodes, arrows, loop_label)
    
    def create_flow_node(self, text, color):
        """Create a flowchart node"""
        box = RoundedRectangle(
            width=4,
            height=0.8,
            fill_color=color,
            fill_opacity=0.3,
            stroke_color=color,
            stroke_width=2,
            corner_radius=0.1
        )
        
        label = Text(text, font_size=18, color=WHITE)
        label.move_to(box.get_center())
        
        return VGroup(box, label)
    
    def animate_flowchart_execution(self, flowchart):
        """Animate data flowing through the flowchart"""
        nodes, arrows, loop_label = flowchart
        
        # Create a data token
        token = Dot(color=YELLOW, radius=0.15)
        token.move_to(nodes[0].get_center())
        
        self.play(FadeIn(token, scale=1.5))
        
        # Move through each node
        for i in range(len(nodes)):
            # Highlight current node
            self.play(
                nodes[i][0].animate.set_fill(opacity=0.6),
                run_time=0.5
            )
            
            if i < len(nodes) - 1:
                # Move to next node
                self.play(
                    token.animate.move_to(nodes[i+1].get_center()),
                    run_time=0.8
                )
                
                # Unhighlight previous node
                self.play(
                    nodes[i][0].animate.set_fill(opacity=0.3),
                    run_time=0.3
                )
        
        # Loop back
        self.play(
            token.animate.move_to(nodes[0].get_center()).set_color(GREEN),
            run_time=1.5
        )
        
        self.play(FadeOut(token))
    
    def show_training_update(self):
        """Show the training update process"""
        title = Text("Stage 3: Training Update", font_size=36, color=PURPLE)
        title.to_edge(UP)
        self.play(Write(title))
        
        # Show TD learning equations
        equations = VGroup(
            MathTex(r"\text{TD Error: } \delta_t = r_t + \gamma V(s_{t+1}) - V(s_t)", font_size=28),
            MathTex(r"\text{Critic Update: } V(s_t) \leftarrow V(s_t) + \alpha_c \delta_t", font_size=28),
            MathTex(r"\text{Actor Update: } \theta \leftarrow \theta + \alpha_a \delta_t \nabla\log\pi(a_t|s_t)", font_size=24)
        ).arrange(DOWN, buff=0.5)
        equations.shift(DOWN * 0.5)
        
        for eq in equations:
            self.play(Write(eq), run_time=1.5)
            self.wait(0.5)
        
        # Add explanation
        explanation = Text(
            "Learning from temporal difference to improve policy",
            font_size=18,
            color=YELLOW
        )
        explanation.to_edge(DOWN)
        self.play(FadeIn(explanation))
        
        self.wait()
    
    def create_step_box(self, number, title, description, color):
        """Create a step box for initialization"""
        # Circle with number
        circle = Circle(radius=0.3, color=color, fill_opacity=0.8)
        num = Text(number, font_size=24, color=WHITE, weight=BOLD)
        num.move_to(circle.get_center())
        number_group = VGroup(circle, num)
        
        # Box
        box = RoundedRectangle(
            width=8,
            height=1,
            stroke_color=color,
            stroke_width=2,
            corner_radius=0.1
        )
        
        # Text
        title_text = Text(title, font_size=20, color=color, weight=BOLD)
        desc_text = Text(description, font_size=14, color=GREY)
        text_group = VGroup(title_text, desc_text).arrange(DOWN, buff=0.1)
        
        # Arrange
        number_group.next_to(box.get_left(), RIGHT, buff=0.3)
        text_group.next_to(number_group, RIGHT, buff=0.5)
        
        return VGroup(box, number_group, text_group)


class DataFlowAnimation(Scene):
    """Animate data flowing through the entire system"""
    
    def construct(self):
        title = Text("Data Flow Through PowerLASCOPF", font_size=42)
        title.to_edge(UP)
        self.play(Write(title))
        
        # Create simplified system diagram
        system = self.create_system_diagram()
        system.scale(0.8).shift(DOWN * 0.5)
        
        self.play(FadeIn(system))
        self.wait()
        
        # Animate multiple timesteps
        for t in range(3):
            self.animate_single_timestep(system, t)
            self.wait(0.5)
        
        self.wait(2)
    
    def create_system_diagram(self):
        """Create system diagram for data flow"""
        # Components
        environment = self.create_labeled_box("Environment\n(Power Grid)", GREEN, 2, 1.5)
        pomdp = self.create_labeled_box("POMDP\nInterface", BLUE, 2, 1.5)
        actor = self.create_labeled_box("Actor\nNetwork", PURPLE, 2, 1.5)
        critic = self.create_labeled_box("Critic\nNetwork", RED, 2, 1.5)
        solver = self.create_labeled_box("ADMM-APP\nSolver", ORANGE, 2, 1.5)
        
        # Layout
        Row1 = VGroup(environment, pomdp).arrange(RIGHT, buff=1.5)
        Row2 = VGroup(actor, critic).arrange(RIGHT, buff=1.5)
        solver.next_to(Row2, DOWN, buff=1)
        
        diagram = VGroup(Row1, Row2, solver)
        diagram.arrange(DOWN, buff=1)
        
        # Connections
        arrows = VGroup(
            Arrow(environment.get_right(), pomdp.get_left(), buff=0.1),
            Arrow(pomdp.get_bottom(), actor.get_top(), buff=0.1),
            Arrow(pomdp.get_bottom(), critic.get_top(), buff=0.1),
            Arrow(actor.get_bottom(), solver.get_top() + LEFT * 0.5, buff=0.1),
            Arrow(solver.get_top() + RIGHT * 0.5, environment.get_left() + DOWN * 0.3, buff=0.1)
        )
        
        return VGroup(diagram, arrows)
    
    def create_labeled_box(self, label, color, width, height):
        """Create a labeled box"""
        box = Rectangle(
            width=width,
            height=height,
            fill_color=color,
            fill_opacity=0.3,
            stroke_color=color,
            stroke_width=2
        )
        text = Text(label, font_size=16, color=WHITE)
        text.move_to(box.get_center())
        return VGroup(box, text)
    
    def animate_single_timestep(self, system, timestep):
        """Animate one timestep of data flow"""
        diagram, arrows = system
        
        # Create data packet
        packet = Circle(radius=0.15, color=YELLOW, fill_opacity=0.8)
        packet.move_to(diagram[0][0].get_center())  # Start at environment
        
        label = Text(f"t={timestep}", font_size=14, color=YELLOW)
        label.next_to(packet, UP, buff=0.1)
        
        self.play(FadeIn(VGroup(packet, label)))
        
        # Move through the system
        path = [
            diagram[0][1],  # POMDP
            diagram[1][0],  # Actor
            diagram[2],     # Solver
            diagram[0][0],  # Back to environment
        ]
        
        for node in path:
            self.play(
                packet.animate.move_to(node.get_center()),
                label.animate.next_to(node.get_center() + UP * 0.8, UP, buff=0.1),
                run_time=1
            )
            self.wait(0.3)
        
        self.play(FadeOut(VGroup(packet, label)))


if __name__ == "__main__":
    print("PowerLASCOPF Main Workflow Animations")
    print("\nAvailable scenes:")
    print("  1. SystemOverview - High-level system architecture")
    print("  2. CompleteWorkflow - Detailed step-by-step workflow")
    print("  3. DataFlowAnimation - Data flow through the system")
    print("\nUsage:")
    print("  manim -pql powerlascopf_main.py SystemOverview")
    print("  manim -pqh powerlascopf_main.py CompleteWorkflow")
