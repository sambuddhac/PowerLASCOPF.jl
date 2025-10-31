"""
PowerLASCOPF Actor-Critic Networks - Detailed Animation
=======================================================
Visualizes the actor and critic neural network architectures across all three frameworks

Usage:
    manim -pql powerlascopf_actor_critic.py ActorCriticOverview
    manim -pql powerlascopf_actor_critic.py FluxActorCritic
    manim -pql powerlascopf_actor_critic.py AllFrameworksComparison
"""

from manim import *
import numpy as np


# Reuse the NeuralNetworkMobject from the original file
class NeuralNetworkMobject(VGroup):
    """Custom mobject for drawing neural networks"""
    
    def __init__(
        self,
        layer_sizes,
        layer_labels=None,
        layer_colors=None,
        neuron_radius=0.12,
        layer_spacing=2.5,
        show_all_edges=True,
        **kwargs
    ):
        super().__init__(**kwargs)
        
        self.layer_sizes = layer_sizes
        self.neuron_radius = neuron_radius
        self.layer_spacing = layer_spacing
        self.show_all_edges = show_all_edges
        
        if layer_colors is None:
            layer_colors = [BLUE] * len(layer_sizes)
        
        self.layers = VGroup()
        self.edges = VGroup()
        self.layer_labels = VGroup()
        
        # Create layers
        for i, size in enumerate(layer_sizes):
            layer = self._create_layer(size, layer_colors[i])
            layer.move_to(RIGHT * i * layer_spacing)
            self.layers.add(layer)
            
            if layer_labels and i < len(layer_labels):
                label = Text(layer_labels[i], font_size=20)
                label.next_to(layer, UP, buff=0.3)
                self.layer_labels.add(label)
        
        # Create edges
        for i in range(len(layer_sizes) - 1):
            layer_edges = self._create_edges(self.layers[i], self.layers[i + 1])
            self.edges.add(layer_edges)
        
        self.add(self.edges, self.layers, self.layer_labels)
        self.center()
    
    def _create_layer(self, size, color):
        """Create a layer of neurons"""
        layer = VGroup()
        max_neurons_shown = 8
        
        neurons_to_show = min(size, max_neurons_shown)
        show_ellipsis = size > max_neurons_shown
        
        if neurons_to_show == 1:
            positions = [0]
        else:
            spacing = 0.4
            total_height = (neurons_to_show - 1) * spacing
            positions = np.linspace(-total_height/2, total_height/2, neurons_to_show)
        
        for pos in positions:
            neuron = Circle(
                radius=self.neuron_radius,
                color=color,
                fill_opacity=0.7,
                stroke_width=2
            )
            neuron.move_to(UP * pos)
            layer.add(neuron)
        
        if show_ellipsis:
            dots = Text("⋮", font_size=30, color=color)
            dots.move_to(DOWN * (positions[-1] + 0.4))
            layer.add(dots)
        
        return layer
    
    def _create_edges(self, layer1, layer2):
        """Create edges between two layers"""
        edges = VGroup()
        
        neurons1 = [n for n in layer1 if isinstance(n, Circle)]
        neurons2 = [n for n in layer2 if isinstance(n, Circle)]
        
        total_possible_edges = len(neurons1) * len(neurons2)
        
        if self.show_all_edges and total_possible_edges <= 200:
            for n1 in neurons1:
                for n2 in neurons2:
                    edge = Line(
                        n1.get_center(),
                        n2.get_center(),
                        stroke_width=0.5,
                        stroke_opacity=0.3,
                        color=GREY
                    )
                    edges.add(edge)
        elif self.show_all_edges:
            for n1 in neurons1:
                for n2 in neurons2:
                    edge = Line(
                        n1.get_center(),
                        n2.get_center(),
                        stroke_width=0.3,
                        stroke_opacity=0.15,
                        color=GREY
                    )
                    edges.add(edge)
        
        return edges


class ActorCriticOverview(Scene):
    """Overview of actor-critic architecture"""
    
    def construct(self):
        title = Text("Actor-Critic Architecture", font_size=48, color=BLUE)
        title.to_edge(UP)
        self.play(Write(title))
        
        subtitle = Text(
            "Dual Network System for Policy and Value Estimation",
            font_size=20,
            color=GREY
        )
        subtitle.next_to(title, DOWN)
        self.play(FadeIn(subtitle))
        self.wait()
        
        # Create actor and critic side by side
        actor_critic = self.create_actor_critic_diagram()
        actor_critic.scale(0.65).shift(DOWN * 0.3)
        
        # Animate appearance
        self.play(FadeIn(actor_critic[0]))  # State input
        self.wait(0.5)
        
        self.play(FadeIn(actor_critic[1]))  # Actor
        self.wait(0.5)
        
        self.play(FadeIn(actor_critic[2]))  # Critic
        self.wait(0.5)
        
        # Show outputs
        self.play(FadeIn(actor_critic[3]), FadeIn(actor_critic[4]))
        self.wait()
        
        # Add equations
        self.show_actor_critic_equations()
        
        self.wait(3)
    
    def create_actor_critic_diagram(self):
        """Create actor-critic diagram"""
        # Shared state input
        state = self.create_component("State s_t", GREEN, width=2, height=1)
        state.shift(LEFT * 4 + UP * 1)
        
        # Actor network
        actor = NeuralNetworkMobject(
            layer_sizes=[128, 256, 64],
            layer_labels=["", "Hidden", ""],
            layer_colors=[BLUE, BLUE, BLUE],
            layer_spacing=1.5,
            neuron_radius=0.08
        )
        actor.scale(0.5).shift(LEFT * 0.5 + DOWN * 0.5)
        
        actor_label = Text("Actor π(a|s)", font_size=24, color=BLUE, weight=BOLD)
        actor_label.next_to(actor, UP, buff=0.5)
        
        actor_output = self.create_component("Actions\na_t ∈ ℝ^n", BLUE, width=2, height=1)
        actor_output.next_to(actor, RIGHT, buff=0.8)
        
        # Critic network
        critic = NeuralNetworkMobject(
            layer_sizes=[128, 256, 64, 1],
            layer_labels=["", "Hidden", "", ""],
            layer_colors=[PURPLE, PURPLE, PURPLE, PURPLE],
            layer_spacing=1.5,
            neuron_radius=0.08
        )
        critic.scale(0.5).shift(RIGHT * 3.5 + DOWN * 0.5)
        
        critic_label = Text("Critic V(s)", font_size=24, color=PURPLE, weight=BOLD)
        critic_label.next_to(critic, UP, buff=0.5)
        
        critic_output = self.create_component("Value\nV(s_t) ∈ ℝ", PURPLE, width=2, height=1)
        critic_output.next_to(critic, RIGHT, buff=0.8)
        
        # Arrows
        arrow1 = Arrow(state.get_bottom(), actor.get_top() + LEFT * 0.5, buff=0.1, color=GREEN)
        arrow2 = Arrow(state.get_bottom(), critic.get_top() + LEFT * 0.5, buff=0.1, color=GREEN)
        
        return VGroup(
            state,
            VGroup(actor, actor_label, actor_output, arrow1),
            VGroup(critic, critic_label, critic_output, arrow2),
            VGroup(actor_output),
            VGroup(critic_output)
        )
    
    def create_component(self, text, color, width=2, height=1):
        """Create a component box"""
        box = Rectangle(
            width=width,
            height=height,
            fill_color=color,
            fill_opacity=0.3,
            stroke_color=color,
            stroke_width=2
        )
        label = Text(text, font_size=16, color=WHITE)
        label.move_to(box.get_center())
        return VGroup(box, label)
    
    def show_actor_critic_equations(self):
        """Show the mathematical formulation"""
        equations = VGroup(
            MathTex(r"\text{Actor: } \pi_\theta(a|s) \text{ - stochastic policy}", font_size=20, color=BLUE),
            MathTex(r"\text{Critic: } V_\phi(s) \text{ - state value function}", font_size=20, color=PURPLE),
            MathTex(r"\text{Advantage: } A(s,a) = Q(s,a) - V(s)", font_size=20, color=YELLOW)
        ).arrange(DOWN, aligned_edge=LEFT, buff=0.3)
        equations.to_edge(DOWN).shift(UP * 0.5)
        
        for eq in equations:
            self.play(Write(eq), run_time=1)
            self.wait(0.3)


class FluxActorCritic(Scene):
    """Detailed Flux.jl actor-critic implementation"""
    
    def construct(self):
        title = Text("Flux.jl Actor-Critic Implementation", font_size=40, color=BLUE)
        title.to_edge(UP)
        self.play(Write(title))
        self.wait()
        
        # Show code structure
        self.show_flux_code()
        
        # Show network architecture
        self.show_flux_networks()
        
        self.wait(3)
    
    def show_flux_code(self):
        """Show Flux.jl code for actor-critic"""
        code_lines = [
            "# Actor Network",
            "actor = Chain(",
            "    Dense(state_dim, 256, relu),",
            "    Dense(256, 128, relu),",
            "    Dense(128, action_dim, tanh)",
            ")",
            "",
            "# Critic Network",
            "critic = Chain(",
            "    Dense(state_dim, 256, relu),",
            "    Dense(256, 128, relu),",
            "    Dense(128, 64, relu),",
            "    Dense(64, 1)",
            ")"
        ]
        
        code = VGroup(*[
            Text(line, font="Monospace", font_size=14, color=GREY_A)
            for line in code_lines
        ]).arrange(DOWN, aligned_edge=LEFT, buff=0.1)
        
        # Syntax highlighting
        code[0].set_color(GREEN)
        code[1].set_color(BLUE)
        code[7].set_color(GREEN)
        code[8].set_color(PURPLE)
        
        code_bg = SurroundingRectangle(
            code,
            color=GREY_D,
            fill_color=BLACK,
            fill_opacity=0.8,
            buff=0.3
        )
        code_group = VGroup(code_bg, code)
        code_group.scale(0.7).to_edge(LEFT).shift(DOWN * 0.3)
        
        self.play(FadeIn(code_group))
        self.wait(2)
        
        return code_group
    
    def show_flux_networks(self):
        """Show Flux.jl network architectures"""
        # Actor
        actor = NeuralNetworkMobject(
            layer_sizes=[128, 256, 128, 64],
            layer_labels=["State", "H1", "H2", "Actions"],
            layer_colors=[GREEN, BLUE, BLUE, ORANGE],
            layer_spacing=1.8,
            neuron_radius=0.08
        )
        actor.scale(0.4).to_edge(RIGHT).shift(UP * 1.5)
        
        actor_title = Text("Actor Network", font_size=20, color=BLUE)
        actor_title.next_to(actor, UP, buff=0.3)
        
        # Critic
        critic = NeuralNetworkMobject(
            layer_sizes=[128, 256, 128, 64, 1],
            layer_labels=["State", "H1", "H2", "H3", "V"],
            layer_colors=[GREEN, PURPLE, PURPLE, PURPLE, ORANGE],
            layer_spacing=1.5,
            neuron_radius=0.08
        )
        critic.scale(0.4).to_edge(RIGHT).shift(DOWN * 1.5)
        
        critic_title = Text("Critic Network", font_size=20, color=PURPLE)
        critic_title.next_to(critic, UP, buff=0.3)
        
        self.play(
            FadeIn(VGroup(actor, actor_title)),
            FadeIn(VGroup(critic, critic_title))
        )
        self.wait()


class PyTorchActorCritic(Scene):
    """PyTorch actor-critic with BatchNorm and Dropout"""
    
    def construct(self):
        title = Text("PyTorch Actor-Critic with Regularization", font_size=38, color=RED)
        title.to_edge(UP)
        self.play(Write(title))
        self.wait()
        
        # Show PyTorch code
        code_lines = [
            "class ActorCritic(nn.Module):",
            "    def __init__(self, state_dim, action_dim):",
            "        # Actor",
            "        self.actor = nn.Sequential(",
            "            nn.Linear(state_dim, 256),",
            "            nn.BatchNorm1d(256),",
            "            nn.ReLU(),",
            "            nn.Dropout(0.1),",
            "            nn.Linear(256, 128),",
            "            nn.Linear(128, action_dim),",
            "            nn.Tanh()",
            "        )",
            "        # Critic similar structure",
        ]
        
        code = VGroup(*[
            Text(line, font="Monospace", font_size=12, color=GREY_A)
            for line in code_lines
        ]).arrange(DOWN, aligned_edge=LEFT, buff=0.1)
        
        code[0].set_color(RED)
        code[2].set_color(GREEN)
        
        code_bg = SurroundingRectangle(code, color=GREY_D, fill_color=BLACK, fill_opacity=0.8, buff=0.3)
        code_group = VGroup(code_bg, code)
        code_group.scale(0.65).to_edge(LEFT).shift(DOWN * 0.5)
        
        self.play(FadeIn(code_group))
        
        # Show block diagram
        self.show_pytorch_blocks()
        self.wait(3)
    
    def show_pytorch_blocks(self):
        """Show PyTorch layer blocks"""
        # Actor block structure
        blocks = VGroup()
        for i in range(2):
            block = self.create_layer_block(f"Block {i+1}")
            blocks.add(block)
        blocks.arrange(DOWN, buff=0.3)
        blocks.scale(0.7).to_edge(RIGHT).shift(DOWN * 0.5)
        
        title = Text("Actor Layer Blocks", font_size=20, color=RED)
        title.next_to(blocks, UP, buff=0.4)
        
        self.play(FadeIn(VGroup(blocks, title)))
    
    def create_layer_block(self, label):
        """Create a layer block showing Linear->BN->ReLU->Dropout"""
        layers = VGroup(
            self.create_mini_box("Linear", BLUE, 1.5, 0.4),
            self.create_mini_box("BatchNorm", PURPLE, 1.5, 0.3),
            self.create_mini_box("ReLU", ORANGE, 1.5, 0.3),
            self.create_mini_box("Dropout", RED, 1.5, 0.3)
        ).arrange(DOWN, buff=0.05)
        
        border = SurroundingRectangle(layers, color=GREY, buff=0.1, stroke_width=2)
        label_text = Text(label, font_size=14, color=GREY)
        label_text.next_to(border, UP, buff=0.1)
        
        return VGroup(border, layers, label_text)
    
    def create_mini_box(self, text, color, width, height):
        """Create a mini box for layer visualization"""
        box = Rectangle(width=width, height=height, fill_color=color, fill_opacity=0.3, stroke_color=color, stroke_width=1)
        label = Text(text, font_size=10, color=WHITE)
        label.move_to(box.get_center())
        return VGroup(box, label)


class TensorFlowActorCritic(Scene):
    """TensorFlow/Keras actor-critic"""
    
    def construct(self):
        title = Text("TensorFlow/Keras Actor-Critic", font_size=38, color="#FF6F00")
        title.to_edge(UP)
        self.play(Write(title))
        self.wait()
        
        # Show TF code
        code_lines = [
            "def create_actor(state_dim, action_dim):",
            "    inputs = Input(shape=(state_dim,))",
            "    x = inputs",
            "    for units in [256, 128]:",
            "        x = Dense(units, activation='relu')(x)",
            "        x = BatchNormalization()(x)",
            "        x = Dropout(0.1)(x)",
            "    actions = Dense(action_dim, activation='tanh')(x)",
            "    return Model(inputs, actions)",
        ]
        
        code = VGroup(*[
            Text(line, font="Monospace", font_size=11, color=GREY_A)
            for line in code_lines
        ]).arrange(DOWN, aligned_edge=LEFT, buff=0.1)
        
        code[0].set_color(ORANGE)
        
        code_bg = SurroundingRectangle(code, color=GREY_D, fill_color=BLACK, fill_opacity=0.8, buff=0.3)
        code_group = VGroup(code_bg, code)
        code_group.scale(0.65).to_edge(LEFT).shift(DOWN * 0.5)
        
        self.play(FadeIn(code_group))
        
        # Show functional API flow
        self.show_tf_flow()
        self.wait(3)
    
    def show_tf_flow(self):
        """Show TensorFlow functional API flow"""
        flow = VGroup(
            self.create_mini_box("Input", GREEN, 1.5, 0.4),
            Text("↓", font_size=20),
            self.create_mini_box("Dense+ReLU", BLUE, 1.5, 0.4),
            Text("↓", font_size=20),
            self.create_mini_box("BatchNorm", PURPLE, 1.5, 0.3),
            Text("↓", font_size=20),
            self.create_mini_box("Dropout", RED, 1.5, 0.3),
            Text("↓", font_size=20),
            self.create_mini_box("Output+Tanh", ORANGE, 1.5, 0.4)
        ).arrange(DOWN, buff=0.15)
        flow.scale(0.8).to_edge(RIGHT).shift(DOWN * 0.5)
        
        title = Text("Functional API Flow", font_size=18, color=ORANGE)
        title.next_to(flow, UP, buff=0.4)
        
        self.play(FadeIn(VGroup(flow, title)))
    
    def create_mini_box(self, text, color, width, height):
        """Create a mini box"""
        box = Rectangle(width=width, height=height, fill_color=color, fill_opacity=0.3, stroke_color=color, stroke_width=2)
        label = Text(text, font_size=12, color=WHITE)
        label.move_to(box.get_center())
        return VGroup(box, label)


class AllFrameworksComparison(Scene):
    """Side-by-side comparison of all three frameworks"""
    
    def construct(self):
        title = Text("Actor-Critic: Framework Comparison", font_size=40)
        title.to_edge(UP)
        self.play(Write(title))
        self.wait()
        
        # Create three columns
        flux_col = self.create_framework_column("Flux.jl", BLUE, [
            "• Pure Julia",
            "• Chain API",
            "• Automatic differentiation",
            "• Zygote.jl backend",
            "• Simple and elegant"
        ])
        
        pytorch_col = self.create_framework_column("PyTorch", RED, [
            "• Python",
            "• Sequential/Module API",
            "• BatchNorm + Dropout",
            "• Dynamic computation graph",
            "• Research friendly"
        ])
        
        tf_col = self.create_framework_column("TensorFlow/Keras", ORANGE, [
            "• Python",
            "• Functional API",
            "• Inline activations",
            "• Static graph (default)",
            "• Production ready"
        ])
        
        columns = VGroup(flux_col, pytorch_col, tf_col)
        columns.arrange(RIGHT, buff=0.8)
        columns.scale(0.75).shift(DOWN * 0.8)
        
        # Animate columns
        for col in columns:
            self.play(FadeIn(col, shift=UP), run_time=0.8)
            self.wait(0.3)
        
        # Add common ground
        common = Text(
            "All implement: Actor π(a|s) + Critic V(s) with TD Learning",
            font_size=18,
            color=YELLOW
        )
        common.to_edge(DOWN)
        self.play(Write(common))
        
        self.wait(3)
    
    def create_framework_column(self, name, color, features):
        """Create a framework comparison column"""
        # Title
        title = Text(name, font_size=24, color=color, weight=BOLD)
        
        # Network icon (simplified)
        network = Rectangle(
            width=2,
            height=1.5,
            fill_color=color,
            fill_opacity=0.2,
            stroke_color=color,
            stroke_width=2
        )
        network_label = Text("Actor-Critic", font_size=12, color=WHITE)
        network_label.move_to(network.get_center())
        network_group = VGroup(network, network_label)
        
        # Features list
        feature_list = VGroup(*[
            Text(feature, font_size=13, color=GREY_A)
            for feature in features
        ]).arrange(DOWN, aligned_edge=LEFT, buff=0.15)
        
        # Arrange
        column = VGroup(title, network_group, feature_list)
        column.arrange(DOWN, buff=0.4)
        
        # Border
        border = SurroundingRectangle(
            column,
            color=color,
            buff=0.3,
            stroke_width=2,
            corner_radius=0.1
        )
        
        return VGroup(border, column)


class TrainingDynamics(Scene):
    """Show training dynamics and learning process"""
    
    def construct(self):
        title = Text("Actor-Critic Training Dynamics", font_size=42, color=PURPLE)
        title.to_edge(UP)
        self.play(Write(title))
        self.wait()
        
        # Show training loop
        self.show_training_loop()
        
        # Show loss curves
        self.show_loss_curves()
        
        self.wait(3)
    
    def show_training_loop(self):
        """Show the training loop"""
        loop_steps = VGroup(
            Text("1. Sample action from policy", font_size=18, color=BLUE),
            Text("2. Execute in environment", font_size=18, color=GREEN),
            Text("3. Compute TD error", font_size=18, color=YELLOW),
            Text("4. Update critic", font_size=18, color=PURPLE),
            Text("5. Update actor", font_size=18, color=RED),
        ).arrange(DOWN, aligned_edge=LEFT, buff=0.3)
        loop_steps.shift(LEFT * 2 + DOWN * 0.5)
        
        for step in loop_steps:
            self.play(FadeIn(step, shift=RIGHT), run_time=0.6)
            self.wait(0.2)
        
        self.wait()
    
    def show_loss_curves(self):
        """Show training loss curves"""
        axes = Axes(
            x_range=[0, 100, 20],
            y_range=[0, 10, 2],
            x_length=5,
            y_length=3,
            axis_config={"include_tip": True}
        )
        axes.to_edge(RIGHT).shift(DOWN * 0.5)
        
        # Create loss curves
        actor_loss = axes.plot(lambda x: 8 * np.exp(-x/30) + 1, color=BLUE)
        critic_loss = axes.plot(lambda x: 7 * np.exp(-x/25) + 0.5, color=PURPLE)
        
        # Labels
        axes_label = Text("Training Progress", font_size=18, color=WHITE)
        axes_label.next_to(axes, UP, buff=0.3)
        
        actor_label = Text("Actor Loss", font_size=14, color=BLUE)
        actor_label.next_to(axes, DOWN, buff=0.3).shift(LEFT * 1)
        
        critic_label = Text("Critic Loss", font_size=14, color=PURPLE)
        critic_label.next_to(actor_label, RIGHT, buff=0.5)
        
        self.play(
            Create(axes),
            Write(axes_label)
        )
        self.play(
            Create(actor_loss),
            Create(critic_loss),
            FadeIn(actor_label),
            FadeIn(critic_label),
            run_time=2
        )
        self.wait()


if __name__ == "__main__":
    print("PowerLASCOPF Actor-Critic Animations")
    print("\nAvailable scenes:")
    print("  1. ActorCriticOverview - High-level actor-critic architecture")
    print("  2. FluxActorCritic - Flux.jl implementation details")
    print("  3. PyTorchActorCritic - PyTorch with regularization")
    print("  4. TensorFlowActorCritic - TensorFlow/Keras functional API")
    print("  5. AllFrameworksComparison - Side-by-side comparison")
    print("  6. TrainingDynamics - Training process and learning curves")
    print("\nUsage:")
    print("  manim -pql powerlascopf_actor_critic.py ActorCriticOverview")
