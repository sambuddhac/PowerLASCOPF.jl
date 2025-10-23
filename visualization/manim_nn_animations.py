"""
3Blue1Brown Style Neural Network Animations
Animates three different neural network architectures:
1. Flux.jl: Simple 3-layer network
2. PyTorch: Network with BatchNorm, Dropout
3. TensorFlow/Keras: Functional API with inline activations

Usage:
    manim -pql neural_networks.py FluxNetwork
    manim -pql neural_networks.py PyTorchNetwork
    manim -pql neural_networks.py TensorFlowNetwork
    manim -pql neural_networks.py AllNetworksComparison
"""

from manim import *
import numpy as np

class NeuralNetworkMobject(VGroup):
    """Custom mobject for drawing neural networks with 3B1B style"""
    
    def __init__(
        self,
        layer_sizes,
        layer_labels=None,
        layer_colors=None,
        neuron_radius=0.12,
        layer_spacing=2.5,
        neuron_stroke_width=2,
        show_all_neurons=False,
        max_neurons_shown=8,
        show_all_edges=True,  # New parameter
        **kwargs
    ):
        super().__init__(**kwargs)
        
        self.layer_sizes = layer_sizes
        self.neuron_radius = neuron_radius
        self.layer_spacing = layer_spacing
        self.max_neurons_shown = max_neurons_shown
        self.show_all_neurons = show_all_neurons
        self.show_all_edges = show_all_edges  # Store the parameter
        
        # Default colors
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
            
            # Add label
            if layer_labels and i < len(layer_labels):
                label = Text(layer_labels[i], font_size=24)
                label.next_to(layer, UP, buff=0.3)
                self.layer_labels.add(label)
        
        # Create edges between layers
        for i in range(len(layer_sizes) - 1):
            layer_edges = self._create_edges(self.layers[i], self.layers[i + 1])
            self.edges.add(layer_edges)
        
        self.add(self.edges, self.layers, self.layer_labels)
        self.center()
    
    def _create_layer(self, size, color):
        """Create a layer of neurons"""
        layer = VGroup()
        
        # Determine how many neurons to show
        if self.show_all_neurons or size <= self.max_neurons_shown:
            neurons_to_show = size
            show_ellipsis = False
        else:
            neurons_to_show = min(size, self.max_neurons_shown)
            show_ellipsis = True
        
        # Calculate vertical spacing
        if neurons_to_show == 1:
            positions = [0]
        else:
            spacing = 0.5
            total_height = (neurons_to_show - 1) * spacing
            positions = np.linspace(-total_height/2, total_height/2, neurons_to_show)
        
        # Create neurons
        for pos in positions:
            neuron = Circle(
                radius=self.neuron_radius,
                color=color,
                fill_opacity=0.7,
                stroke_width=2
            )
            neuron.move_to(UP * pos)
            layer.add(neuron)
        
        # Add ellipsis if needed
        if show_ellipsis:
            dots = Text("⋮", font_size=36, color=color)
            dots.move_to(DOWN * (positions[-1] + 0.5))
            layer.add(dots)
        
        return layer
    
    def _create_edges(self, layer1, layer2):
        """Create edges between two layers"""
        edges = VGroup()
        
        # Get actual neurons (not ellipsis)
        neurons1 = [n for n in layer1 if isinstance(n, Circle)]
        neurons2 = [n for n in layer2 if isinstance(n, Circle)]
        
        # Determine if we should show all edges or sample
        total_possible_edges = len(neurons1) * len(neurons2)
        
        if self.show_all_edges and total_possible_edges <= 200:
            # Show all edges for small networks
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
        elif self.show_all_edges and total_possible_edges > 200:
            # For very large networks, still show all but make them lighter
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
        else:
            # For larger networks with show_all_edges=False, show representative connections
            # Connect each neuron to multiple neurons in next layer
            connections_per_neuron = max(3, min(8, len(neurons2) // 2))
            
            for n1 in neurons1:
                # Sample connections to distribute across the layer
                if len(neurons2) <= connections_per_neuron:
                    connected_neurons = neurons2
                else:
                    # Evenly distribute connections across the layer
                    indices = np.linspace(0, len(neurons2) - 1, connections_per_neuron, dtype=int)
                    connected_neurons = [neurons2[i] for i in indices]
                
                for n2 in connected_neurons:
                    edge = Line(
                        n1.get_center(),
                        n2.get_center(),
                        stroke_width=0.5,
                        stroke_opacity=0.25,
                        color=GREY
                    )
                    edges.add(edge)
        
        return edges
    
    def get_neurons_in_layer(self, layer_index):
        """Get all neurons in a specific layer"""
        return [n for n in self.layers[layer_index] if isinstance(n, Circle)]


class FluxNetwork(Scene):
    """Animation for the simple Flux.jl 3-layer network"""
    
    def construct(self):
        # Title
        title = Text("Flux.jl Neural Network", font_size=48, color=BLUE)
        title.to_edge(UP)
        self.play(Write(title))
        self.wait()
        
        # Subtitle
        subtitle = Text(
            "Chain(Dense(input→64, relu), Dense(64→64, relu), Dense(64→output, softmax))",
            font_size=20,
            color=GREY
        )
        subtitle.next_to(title, DOWN)
        self.play(FadeIn(subtitle))
        self.wait()
        
        # Create code using Text instead of Code for better compatibility
        code_lines = [
            "model = Chain(",
            "    Dense(input_size, 64, relu),",
            "    Dense(64, 64, relu),",
            "    Dense(64, output_size, softmax)",
            ")"
        ]
        
        code = VGroup(*[
            Text(line, font="Monospace", font_size=18, color=GREY_A)
            for line in code_lines
        ]).arrange(DOWN, aligned_edge=LEFT, buff=0.15)
        
        # Add syntax highlighting
        code[0].set_color(BLUE)  # model
        code[1].set_color(GREEN)  # Dense
        code[2].set_color(GREEN)  # Dense
        code[3].set_color(GREEN)  # Dense
        code[4].set_color(BLUE)  # )
        
        code_bg = SurroundingRectangle(
            code,
            color=GREY_D,
            fill_color=BLACK,
            fill_opacity=0.8,
            buff=0.3,
            corner_radius=0.1
        )
        code_group = VGroup(code_bg, code)
        code_group.scale(0.7).to_edge(LEFT).shift(DOWN * 0.5)
        code.to_edge(LEFT).shift(DOWN * 0.5)
        
        self.play(Create(code))
        self.wait()
        
        # Create network
        network = NeuralNetworkMobject(
            layer_sizes=[10, 64, 64, 4],
            layer_labels=["Input\n(10)", "Hidden 1\n(64)", "Hidden 2\n(64)", "Output\n(4)"],
            layer_colors=[GREEN, BLUE, BLUE, ORANGE],
            layer_spacing=2.0,
            neuron_radius=0.1
        )
        network.scale(0.6).to_edge(RIGHT).shift(DOWN * 0.5)
        
        # Animate network construction layer by layer
        self.play(
            FadeIn(network.layers[0]),
            FadeIn(network.layer_labels[0])
        )
        self.wait(0.5)
        
        for i in range(1, len(network.layers)):
            self.play(
                Create(network.edges[i-1]),
                FadeIn(network.layers[i]),
                FadeIn(network.layer_labels[i]),
                run_time=1
            )
            self.wait(0.3)
        
        # Add activation labels
        relu1 = Text("ReLU", font_size=18, color=YELLOW).next_to(network.layers[1], DOWN, buff=0.2)
        relu2 = Text("ReLU", font_size=18, color=YELLOW).next_to(network.layers[2], DOWN, buff=0.2)
        softmax = Text("Softmax", font_size=18, color=YELLOW).next_to(network.layers[3], DOWN, buff=0.2)
        
        self.play(
            FadeIn(relu1),
            FadeIn(relu2),
            FadeIn(softmax)
        )
        self.wait()
        
        # Animate forward pass
        self.animate_forward_pass(network)
        
        # Show parameter count
        param_text = Text(
            "Total Parameters: input×64 + 64 + 64×64 + 64 + 64×output + output",
            font_size=20,
            color=YELLOW
        )
        param_text.to_edge(DOWN)
        self.play(Write(param_text))
        self.wait(2)
    
    def animate_forward_pass(self, network):
        """Animate data flowing through the network"""
        # Create glowing effect for forward pass
        for i in range(len(network.layers)):
            layer = network.layers[i]
            neurons = [n for n in layer if isinstance(n, Circle)]
            
            # Highlight neurons
            animations = []
            for neuron in neurons:
                animations.append(
                    neuron.animate.set_fill(opacity=1).set_stroke(width=4)
                )
            
            if animations:
                self.play(*animations, run_time=0.5)
            
            # Flash edges to next layer
            if i < len(network.edges):
                self.play(
                    network.edges[i].animate.set_stroke(opacity=0.8, width=2),
                    run_time=0.3
                )
                self.play(
                    network.edges[i].animate.set_stroke(opacity=0.3, width=0.5),
                    run_time=0.2
                )
            
            self.wait(0.2)


class PyTorchNetwork(Scene):
    """Animation for PyTorch network with BatchNorm and Dropout"""
    
    def construct(self):
        # Title
        title = Text("PyTorch Neural Network", font_size=48, color=RED)
        title.to_edge(UP)
        self.play(Write(title))
        self.wait()
        
        # Subtitle
        subtitle = Text(
            "Linear → BatchNorm → ReLU → Dropout (repeated)",
            font_size=20,
            color=GREY
        )
        subtitle.next_to(title, DOWN)
        self.play(FadeIn(subtitle))
        self.wait()
        
        # Create code using Text
        code_lines = [
            "for hidden_dim in hidden_dims:",
            "    self.layers.append(nn.Linear(prev_dim, hidden_dim))",
            "    self.layers.append(nn.BatchNorm1d(hidden_dim))",
            "    self.layers.append(nn.ReLU())",
            "    self.layers.append(nn.Dropout(0.1))",
            "    prev_dim = hidden_dim",
            "",
            "self.layers.append(nn.Linear(prev_dim, action_dim))",
            "self.layers.append(nn.Tanh())"
        ]
        
        code = VGroup(*[
            Text(line, font="Monospace", font_size=14, color=GREY_A)
            for line in code_lines
        ]).arrange(DOWN, aligned_edge=LEFT, buff=0.12)
        
        # Syntax highlighting
        code[0].set_color(BLUE)
        code[1][0:16].set_color(GREEN)
        code[2][0:16].set_color(PURPLE)
        code[3][0:16].set_color(ORANGE)
        code[4][0:16].set_color(RED)
        code[7][0:16].set_color(GREEN)
        code[8][0:16].set_color(ORANGE)
        
        code_bg = SurroundingRectangle(
            code,
            color=GREY_D,
            fill_color=BLACK,
            fill_opacity=0.8,
            buff=0.3,
            corner_radius=0.1
        )
        code_group = VGroup(code_bg, code)
        code_group.scale(0.65).to_corner(UL).shift(DOWN * 1.8 + RIGHT * 0.2)
        
        self.play(FadeIn(code_group))
        self.wait()
        
        # Create layered block diagram
        self.show_pytorch_architecture()
        self.wait(2)
    
    def show_pytorch_architecture(self):
        """Show the layered architecture with special layers"""
        
        # Create input
        input_box = self.create_layer_box("Input\n(state_dim)", GREEN, height=1.5)
        input_box.to_edge(LEFT).shift(DOWN * 0.5)
        self.play(FadeIn(input_box))
        
        current_pos = input_box.get_right() + RIGHT * 0.5
        
        # Create hidden block (showing the pattern)
        hidden_blocks = VGroup()
        
        for i in range(3):
            block = self.create_hidden_block(i + 1)
            block.next_to(current_pos, RIGHT, buff=0.3)
            hidden_blocks.add(block)
            
            # Animate block appearance
            self.play(FadeIn(block), run_time=0.8)
            
            # Draw arrow
            if i < 2:
                arrow = Arrow(
                    block.get_right(),
                    block.get_right() + RIGHT * 0.3,
                    buff=0.1,
                    color=WHITE,
                    stroke_width=3
                )
                self.play(GrowArrow(arrow), run_time=0.3)
                current_pos = arrow.get_right()
            else:
                current_pos = block.get_right()
        
        # Create output
        output_block = VGroup(
            self.create_layer_box("Linear", BLUE, height=0.8),
            self.create_layer_box("Tanh\n[-1,1]", ORANGE, height=0.6)
        ).arrange(DOWN, buff=0.1)
        
        output_block.next_to(current_pos, RIGHT, buff=0.5)
        self.play(FadeIn(output_block))
        
        # Add final label
        output_label = Text("Output\n(action_dim)", font_size=18)
        output_label.next_to(output_block, DOWN)
        self.play(FadeIn(output_label))
        
        self.wait()
    
    def create_hidden_block(self, num):
        """Create a single hidden block with all components"""
        # Create individual layer boxes
        linear = self.create_layer_box("Linear", BLUE, height=0.8)
        batchnorm = self.create_layer_box("BatchNorm", PURPLE, height=0.6)
        relu = self.create_layer_box("ReLU", ORANGE, height=0.5)
        dropout = self.create_layer_box("Dropout\n(0.1)", RED, height=0.5)
        
        # Arrange vertically
        block = VGroup(linear, batchnorm, relu, dropout).arrange(DOWN, buff=0.05)
        
        # Add border around block
        border = SurroundingRectangle(
            block,
            color=GREY,
            buff=0.15,
            corner_radius=0.1,
            stroke_width=2
        )
        
        # Add label
        label = Text(f"Block {num}", font_size=16, color=GREY)
        label.next_to(border, UP, buff=0.1)
        
        return VGroup(border, block, label)
    
    def create_layer_box(self, text, color, width=1.5, height=0.6):
        """Create a colored box representing a layer"""
        box = Rectangle(
            width=width,
            height=height,
            fill_color=color,
            fill_opacity=0.3,
            stroke_color=color,
            stroke_width=2
        )
        
        label = Text(text, font_size=14, color=WHITE)
        label.move_to(box.get_center())
        
        return VGroup(box, label)


class TensorFlowNetwork(Scene):
    """Animation for TensorFlow/Keras functional API network"""
    
    def construct(self):
        # Title
        title = Text("TensorFlow/Keras Functional API", font_size=44, color="#FF6F00")
        title.to_edge(UP)
        self.play(Write(title))
        self.wait()
        
        # Subtitle
        subtitle = Text(
            "Dense(activation='relu') → BatchNorm → Dropout",
            font_size=20,
            color=GREY
        )
        subtitle.next_to(title, DOWN)
        self.play(FadeIn(subtitle))
        self.wait()
        
        # Create code using Text
        code_lines = [
            "inputs = tf.keras.layers.Input(shape=(state_dim,))",
            "",
            "x = inputs",
            "for hidden_dim in hidden_dims:",
            "    x = tf.keras.layers.Dense(",
            "        hidden_dim, activation='relu')(x)",
            "    x = tf.keras.layers.BatchNormalization()(x)",
            "    x = tf.keras.layers.Dropout(0.1)(x)",
            "",
            "actions = tf.keras.layers.Dense(",
            "    action_dim, activation='tanh')(x)"
        ]
        
        code = VGroup(*[
            Text(line, font="Monospace", font_size=13, color=GREY_A)
            for line in code_lines
        ]).arrange(DOWN, aligned_edge=LEFT, buff=0.12)
        
        # Syntax highlighting
        code[0].set_color(GREEN)
        code[3].set_color(BLUE)
        code[4][0:8].set_color(BLUE)
        code[6][0:8].set_color(PURPLE)
        code[7][0:8].set_color(RED)
        code[9].set_color(ORANGE)
        
        code_bg = SurroundingRectangle(
            code,
            color=GREY_D,
            fill_color=BLACK,
            fill_opacity=0.8,
            buff=0.3,
            corner_radius=0.1
        )
        code_group = VGroup(code_bg, code)
        code_group.scale(0.55).to_corner(UL).shift(DOWN * 1.5)
        
        self.play(FadeIn(code_group))
        self.wait()
        
        # Show architecture with emphasis on activation order
        self.show_tensorflow_architecture()
        self.wait(2)
    
    def show_tensorflow_architecture(self):
        """Show TensorFlow architecture with activation inline"""
        
        # Create input
        input_box = self.create_layer_box("Input", GREEN, height=1.2)
        input_box.to_edge(LEFT).shift(DOWN * 0.5)
        self.play(FadeIn(input_box))
        
        current_pos = input_box.get_right() + RIGHT * 0.5
        
        # Create hidden blocks
        for i in range(3):
            block = self.create_tf_hidden_block(i + 1)
            block.next_to(current_pos, RIGHT, buff=0.3)
            
            # Animate block with emphasis on Dense+ReLU
            self.play(FadeIn(block), run_time=0.8)
            
            if i < 2:
                arrow = Arrow(
                    block.get_right(),
                    block.get_right() + RIGHT * 0.3,
                    buff=0.1,
                    color=WHITE,
                    stroke_width=3
                )
                self.play(GrowArrow(arrow), run_time=0.3)
                current_pos = arrow.get_right()
            else:
                current_pos = block.get_right()
        
        # Create output
        output_box = self.create_layer_box("Dense+Tanh\n(actions)", ORANGE, width=1.8, height=1.0)
        output_box.next_to(current_pos, RIGHT, buff=0.5)
        self.play(FadeIn(output_box))
        
        # Add note about activation order
        note = Text(
            "Note: Activation applied BEFORE BatchNorm",
            font_size=18,
            color=YELLOW
        ).to_edge(DOWN)
        self.play(Write(note))
        
        self.wait()
    
    def create_tf_hidden_block(self, num):
        """Create TensorFlow-style hidden block"""
        # Dense with inline activation (emphasized)
        dense_relu = Rectangle(
            width=1.8,
            height=0.9,
            fill_color=BLUE,
            fill_opacity=0.4,
            stroke_color=BLUE,
            stroke_width=3
        )
        dense_label = Text("Dense\n+ ReLU", font_size=14, color=WHITE)
        dense_label.move_to(dense_relu.get_center())
        dense_combined = VGroup(dense_relu, dense_label)
        
        # BatchNorm and Dropout
        batchnorm = self.create_layer_box("BatchNorm", PURPLE, height=0.6, width=1.8)
        dropout = self.create_layer_box("Dropout", RED, height=0.5, width=1.8)
        
        block = VGroup(dense_combined, batchnorm, dropout).arrange(DOWN, buff=0.05)
        
        # Border
        border = SurroundingRectangle(
            block,
            color="#FF6F00",
            buff=0.15,
            corner_radius=0.1,
            stroke_width=2
        )
        
        label = Text(f"Block {num}", font_size=16, color=GREY)
        label.next_to(border, UP, buff=0.1)
        
        return VGroup(border, block, label)
    
    def create_layer_box(self, text, color, width=1.5, height=0.6):
        """Create a colored box representing a layer"""
        box = Rectangle(
            width=width,
            height=height,
            fill_color=color,
            fill_opacity=0.3,
            stroke_color=color,
            stroke_width=2
        )
        
        label = Text(text, font_size=14, color=WHITE)
        label.move_to(box.get_center())
        
        return VGroup(box, label)


class AllNetworksComparison(Scene):
    """Side-by-side comparison of all three architectures"""
    
    def construct(self):
        # Title
        title = Text("Neural Network Architectures Comparison", font_size=42)
        title.to_edge(UP)
        self.play(Write(title))
        self.wait()
        
        # Create three columns
        flux_section = self.create_flux_summary()
        pytorch_section = self.create_pytorch_summary()
        tf_section = self.create_tensorflow_summary()
        
        # Arrange in columns
        flux_section.scale(0.7).to_edge(LEFT).shift(DOWN * 0.5)
        pytorch_section.scale(0.7).shift(DOWN * 0.5)
        tf_section.scale(0.7).to_edge(RIGHT).shift(DOWN * 0.5)
        
        # Animate all three
        self.play(
            FadeIn(flux_section),
            FadeIn(pytorch_section),
            FadeIn(tf_section),
            run_time=2
        )
        self.wait()
        
        # Highlight key differences
        self.highlight_differences(flux_section, pytorch_section, tf_section)
        self.wait(3)
    
    def create_flux_summary(self):
        """Create Flux.jl summary"""
        title = Text("Flux.jl", font_size=28, color=BLUE)
        
        network = NeuralNetworkMobject(
            layer_sizes=[8, 64, 64, 4],
            layer_colors=[GREEN, BLUE, BLUE, ORANGE],
            layer_spacing=1.2,
            neuron_radius=0.08,
            show_all_neurons=False
        ).scale(0.5)
        
        description = Text(
            "Simple & Clean\n3 Dense layers\nReLU + Softmax",
            font_size=16,
            color=GREY
        )
        
        return VGroup(title, network, description).arrange(DOWN, buff=0.4)
    
    def create_pytorch_summary(self):
        """Create PyTorch summary"""
        title = Text("PyTorch", font_size=28, color=RED)
        
        # Create block diagram
        blocks = VGroup()
        for i in range(2):
            block = Rectangle(width=1.5, height=1.2, color=BLUE, stroke_width=2)
            label = Text("Linear→BN\n→ReLU→Drop", font_size=10)
            label.move_to(block)
            blocks.add(VGroup(block, label))
        blocks.arrange(RIGHT, buff=0.3)
        
        description = Text(
            "Modular Design\nBatchNorm after Linear\nDropout for regularization",
            font_size=14,
            color=GREY
        )
        
        return VGroup(title, blocks, description).arrange(DOWN, buff=0.4)
    
    def create_tensorflow_summary(self):
        """Create TensorFlow summary"""
        title = Text("TensorFlow/Keras", font_size=26, color="#FF6F00")
        
        # Create block diagram
        blocks = VGroup()
        for i in range(2):
            block = Rectangle(width=1.5, height=1.2, color=BLUE, stroke_width=2)
            label = Text("Dense+ReLU\n→BN→Drop", font_size=10)
            label.move_to(block)
            blocks.add(VGroup(block, label))
        blocks.arrange(RIGHT, buff=0.3)
        
        description = Text(
            "Functional API\nActivation inline\nBatchNorm after activation",
            font_size=14,
            color=GREY
        )
        
        return VGroup(title, blocks, description).arrange(DOWN, buff=0.4)
    
    def highlight_differences(self, flux, pytorch, tf):
        """Highlight the key architectural differences"""
        
        # Draw comparison arrows
        difference_text = Text(
            "Key Difference: Layer Ordering & Activation Placement",
            font_size=20,
            color=YELLOW
        )
        difference_text.to_edge(DOWN)
        
        self.play(Write(difference_text))
        
        # Highlight each architecture briefly
        for section, color in [(flux, BLUE), (pytorch, RED), (tf, "#FF6F00")]:
            self.play(
                section.animate.set_stroke(color=color, width=4),
                run_time=0.5
            )
            self.play(
                section.animate.set_stroke(width=0),
                run_time=0.5
            )
        
        self.wait()


# Additional scene: Forward propagation visualization
class ForwardPropagation(Scene):
    """Detailed forward propagation animation"""
    
    def construct(self):
        title = Text("Forward Propagation", font_size=48)
        title.to_edge(UP)
        self.play(Write(title))
        
        # Create simple network
        network = NeuralNetworkMobject(
            layer_sizes=[4, 6, 6, 3],
            layer_labels=["Input", "Hidden 1", "Hidden 2", "Output"],
            layer_colors=[GREEN, BLUE, BLUE, ORANGE],
            layer_spacing=2.5,
            neuron_radius=0.15,
            show_all_neurons=True
        )
        network.scale(0.8).shift(DOWN * 0.5)
        
        self.play(FadeIn(network))
        self.wait()
        
        # Animate data flowing with values
        self.animate_detailed_forward_pass(network)
        self.wait(2)
    
    def animate_detailed_forward_pass(self, network):
        """Animate forward pass with activation values"""
        
        for layer_idx in range(len(network.layers)):
            layer = network.layers[layer_idx]
            neurons = [n for n in layer if isinstance(n, Circle)]
            
            # Generate random activation values
            activations = np.random.rand(len(neurons))
            
            # Animate neuron activations
            animations = []
            for neuron, activation in zip(neurons, activations):
                # Color intensity based on activation
                color = interpolate_color(BLUE_E, YELLOW, activation)
                animations.append(
                    neuron.animate.set_fill(color=color, opacity=0.8)
                )
                
                # Add value label
                value_label = Text(
                    f"{activation:.2f}",
                    font_size=12,
                    color=WHITE
                )
                value_label.move_to(neuron.get_center())
                animations.append(FadeIn(value_label, run_time=0.3))
            
            self.play(*animations, run_time=0.8)
            
            # Animate edge weights
            if layer_idx < len(network.edges):
                self.play(
                    network.edges[layer_idx].animate.set_stroke(
                        opacity=0.6,
                        width=1.5,
                        color=YELLOW
                    ),
                    run_time=0.5
                )
            
            self.wait(0.3)


# Scene for explaining BatchNorm
class BatchNormExplanation(Scene):
    """Explain what BatchNorm does"""
    
    def construct(self):
        title = Text("Batch Normalization", font_size=48, color=PURPLE)
        title.to_edge(UP)
        self.play(Write(title))
        
        # Show formula
        formula = MathTex(
            r"\hat{x} = \frac{x - \mu}{\sqrt{\sigma^2 + \epsilon}}",
            font_size=60
        )
        formula.shift(UP)
        
        self.play(Write(formula))
        self.wait()
        
        # Show what it does
        explanation = VGroup(
            Text("1. Normalizes activations", font_size=24),
            Text("2. Reduces internal covariate shift", font_size=24),
            Text("3. Allows higher learning rates", font_size=24),
            Text("4. Acts as regularization", font_size=24)
        ).arrange(DOWN, aligned_edge=LEFT, buff=0.3)
        explanation.shift(DOWN)
        
        self.play(FadeIn(explanation, shift=UP))
        self.wait(2)


class DropoutVisualization(Scene):
    """Visualize how dropout works during training"""
    
    def construct(self):
        title = Text("Dropout Regularization (p=0.1)", font_size=48, color=RED)
        title.to_edge(UP)
        self.play(Write(title))
        
        # Create a layer of neurons
        neurons = VGroup(*[
            Circle(radius=0.2, color=BLUE, fill_opacity=0.7, stroke_width=2)
            for _ in range(20)
        ]).arrange_in_grid(rows=4, cols=5, buff=0.5)
        neurons.shift(DOWN * 0.5)
        
        self.play(FadeIn(neurons))
        self.wait()
        
        # Training mode label
        train_label = Text("Training Mode", font_size=30, color=GREEN)
        train_label.to_edge(DOWN)
        self.play(Write(train_label))
        
        # Simulate dropout over several iterations
        for iteration in range(5):
            # Randomly drop 10% of neurons
            dropped_indices = np.random.choice(20, size=2, replace=False)
            
            animations = []
            for i, neuron in enumerate(neurons):
                if i in dropped_indices:
                    # Drop this neuron
                    animations.append(
                        neuron.animate.set_fill(opacity=0.1).set_stroke(opacity=0.3)
                    )
                    # Add X mark
                    x_mark = Text("×", font_size=40, color=RED)
                    x_mark.move_to(neuron.get_center())
                    animations.append(FadeIn(x_mark))
                else:
                    # Keep active
                    animations.append(
                        neuron.animate.set_fill(opacity=0.7).set_stroke(opacity=1)
                    )
            
            self.play(*animations, run_time=0.8)
            self.wait(0.5)
            
            # Remove X marks
            self.play(
                *[FadeOut(mob) for mob in self.mobjects if isinstance(mob, Text) and mob.text == "×"],
                run_time=0.3
            )
        
        # Switch to inference mode
        self.play(
            train_label.animate.become(
                Text("Inference Mode - All Neurons Active", font_size=30, color=YELLOW)
                .to_edge(DOWN)
            )
        )
        
        # Show all neurons active
        self.play(
            *[neuron.animate.set_fill(opacity=0.7).set_stroke(opacity=1) 
              for neuron in neurons],
            run_time=1
        )
        self.wait(2)


class ActivationFunctions(Scene):
    """Compare different activation functions"""
    
    def construct(self):
        title = Text("Activation Functions", font_size=48)
        title.to_edge(UP)
        self.play(Write(title))
        
        # Create axes for each activation
        axes_config = {
            "x_range": [-3, 3, 1],
            "y_range": [-1.5, 1.5, 0.5],
            "x_length": 4,
            "y_length": 3,
            "tips": False
        }
        
        # ReLU
        relu_axes = Axes(**axes_config)
        relu_graph = relu_axes.plot(lambda x: max(0, x), color=BLUE)
        relu_label = Text("ReLU", font_size=24, color=BLUE)
        relu_formula = MathTex(r"f(x) = \max(0, x)", font_size=20)
        relu_group = VGroup(
            relu_axes, relu_graph, 
            relu_label.next_to(relu_axes, UP),
            relu_formula.next_to(relu_axes, DOWN)
        )
        
        # Tanh
        tanh_axes = Axes(**axes_config)
        tanh_graph = tanh_axes.plot(lambda x: np.tanh(x), color=ORANGE)
        tanh_label = Text("Tanh", font_size=24, color=ORANGE)
        tanh_formula = MathTex(r"f(x) = \tanh(x)", font_size=20)
        tanh_group = VGroup(
            tanh_axes, tanh_graph,
            tanh_label.next_to(tanh_axes, UP),
            tanh_formula.next_to(tanh_axes, DOWN)
        )
        
        # Softmax (conceptual)
        softmax_text = Text("Softmax", font_size=24, color=GREEN)
        softmax_formula = MathTex(
            r"\sigma(x)_i = \frac{e^{x_i}}{\sum_j e^{x_j}}",
            font_size=20
        )
        softmax_desc = Text(
            "Converts to probabilities\nSum = 1.0",
            font_size=16,
            color=GREY
        )
        softmax_group = VGroup(
            softmax_text,
            softmax_formula.next_to(softmax_text, DOWN),
            softmax_desc.next_to(softmax_formula, DOWN)
        )
        
        # Arrange all three
        relu_group.scale(0.7).to_edge(LEFT).shift(DOWN * 0.5)
        tanh_group.scale(0.7).shift(DOWN * 0.5)
        softmax_group.scale(0.7).to_edge(RIGHT).shift(DOWN * 0.5)
        
        # Animate each
        self.play(Create(relu_group), run_time=1.5)
        self.wait(0.5)
        self.play(Create(tanh_group), run_time=1.5)
        self.wait(0.5)
        self.play(FadeIn(softmax_group), run_time=1.5)
        
        # Add characteristics
        relu_char = Text("• Non-linear\n• Fast\n• Dead neurons", font_size=12, color=GREY)
        relu_char.next_to(relu_group, DOWN, buff=0.3)
        
        tanh_char = Text("• Bounded [-1,1]\n• Zero-centered\n• Smooth", font_size=12, color=GREY)
        tanh_char.next_to(tanh_group, DOWN, buff=0.3)
        
        softmax_char = Text("• Multi-class\n• Probabilities\n• Output layer", font_size=12, color=GREY)
        softmax_char.next_to(softmax_group, DOWN, buff=0.3)
        
        self.play(
            FadeIn(relu_char),
            FadeIn(tanh_char),
            FadeIn(softmax_char)
        )
        self.wait(3)


class ArchitectureEvolution(Scene):
    """Show how architectures evolved from simple to complex"""
    
    def construct(self):
        title = Text("Neural Network Evolution", font_size=48)
        title.to_edge(UP)
        self.play(Write(title))
        
        # Stage 1: Simple perceptron
        stage1_title = Text("1. Simple Perceptron (1958)", font_size=24, color=BLUE)
        stage1_title.next_to(title, DOWN, buff=0.5)
        
        simple_net = NeuralNetworkMobject(
            layer_sizes=[3, 1],
            layer_colors=[GREEN, ORANGE],
            layer_spacing=3,
            neuron_radius=0.15,
            show_all_neurons=True
        ).scale(0.6)
        
        self.play(Write(stage1_title))
        self.play(FadeIn(simple_net))
        self.wait(1.5)
        
        # Stage 2: Multi-layer (1980s)
        stage2_title = Text("2. Multi-Layer Perceptron (1986)", font_size=24, color=BLUE)
        stage2_net = NeuralNetworkMobject(
            layer_sizes=[4, 6, 3],
            layer_colors=[GREEN, BLUE, ORANGE],
            layer_spacing=2.5,
            neuron_radius=0.12
        ).scale(0.6)
        
        self.play(
            Transform(stage1_title, stage2_title.next_to(title, DOWN, buff=0.5)),
            Transform(simple_net, stage2_net)
        )
        self.wait(1.5)
        
        # Stage 3: Deep networks with regularization (2010s)
        stage3_title = Text("3. Deep Networks + BatchNorm + Dropout (2015)", font_size=22, color=BLUE)
        stage3_net = NeuralNetworkMobject(
            layer_sizes=[8, 64, 64, 32, 4],
            layer_colors=[GREEN, BLUE, BLUE, BLUE, ORANGE],
            layer_spacing=1.8,
            neuron_radius=0.08
        ).scale(0.6)
        
        self.play(
            Transform(stage1_title, stage3_title.next_to(title, DOWN, buff=0.5)),
            Transform(simple_net, stage3_net)
        )
        self.wait(2)
        
        # Add modern features labels
        features = VGroup(
            Text("• Batch Normalization", font_size=16, color=PURPLE),
            Text("• Dropout Regularization", font_size=16, color=RED),
            Text("• Advanced Optimizers (Adam)", font_size=16, color=YELLOW),
            Text("• Skip Connections (ResNet)", font_size=16, color=GREEN),
            Text("• Attention Mechanisms", font_size=16, color=ORANGE)
        ).arrange(DOWN, aligned_edge=LEFT, buff=0.2)
        features.to_edge(DOWN)
        
        self.play(FadeIn(features, shift=UP))
        self.wait(3)


class ParameterCount(Scene):
    """Visualize parameter counts and computational complexity"""
    
    def construct(self):
        title = Text("Understanding Network Parameters", font_size=44)
        title.to_edge(UP)
        self.play(Write(title))
        
        # Show simple example: 3 → 5 → 2
        network = NeuralNetworkMobject(
            layer_sizes=[3, 5, 2],
            layer_labels=["Input (3)", "Hidden (5)", "Output (2)"],
            layer_colors=[GREEN, BLUE, ORANGE],
            layer_spacing=3,
            neuron_radius=0.15,
            show_all_neurons=True
        )
        network.scale(0.7).shift(UP * 0.5)
        
        self.play(FadeIn(network))
        self.wait()
        
        # Calculate parameters for first layer
        layer1_calc = VGroup(
            Text("Layer 1: Input → Hidden", font_size=24, color=BLUE),
            MathTex(r"Weights: 3 \times 5 = 15", font_size=20),
            MathTex(r"Biases: 5", font_size=20),
            MathTex(r"Total: 20 \text{ parameters}", font_size=20, color=YELLOW)
        ).arrange(DOWN, aligned_edge=LEFT, buff=0.2)
        layer1_calc.to_corner(DL)
        
        # Highlight first layer connections
        self.play(
            network.edges[0].animate.set_stroke(color=YELLOW, width=2, opacity=0.8),
            Write(layer1_calc),
            run_time=2
        )
        self.wait()
        
        # Calculate parameters for second layer
        layer2_calc = VGroup(
            Text("Layer 2: Hidden → Output", font_size=24, color=ORANGE),
            MathTex(r"Weights: 5 \times 2 = 10", font_size=20),
            MathTex(r"Biases: 2", font_size=20),
            MathTex(r"Total: 12 \text{ parameters}", font_size=20, color=YELLOW)
        ).arrange(DOWN, aligned_edge=LEFT, buff=0.2)
        layer2_calc.to_corner(DR)
        
        self.play(
            network.edges[0].animate.set_stroke(color=GREY, width=0.5, opacity=0.3),
            network.edges[1].animate.set_stroke(color=YELLOW, width=2, opacity=0.8),
            Write(layer2_calc),
            run_time=2
        )
        self.wait()
        
        # Total
        total = VGroup(
            Text("Total Network Parameters", font_size=28, color=GREEN),
            MathTex(r"20 + 12 = 32 \text{ parameters}", font_size=24)
        ).arrange(DOWN, buff=0.3)
        total.move_to(DOWN * 2.5)
        
        self.play(
            network.edges[1].animate.set_stroke(color=GREY, width=0.5, opacity=0.3),
            FadeIn(total, scale=1.2),
            run_time=1.5
        )
        self.wait(2)


class TrainingVsInference(Scene):
    """Show difference between training and inference mode"""
    
    def construct(self):
        title = Text("Training vs Inference", font_size=48)
        title.to_edge(UP)
        self.play(Write(title))
        
        # Create two identical networks
        train_net = NeuralNetworkMobject(
            layer_sizes=[4, 8, 8, 3],
            layer_colors=[GREEN, BLUE, BLUE, ORANGE],
            layer_spacing=1.5,
            neuron_radius=0.1
        ).scale(0.5).shift(LEFT * 3.5 + DOWN * 0.5)
        
        infer_net = train_net.copy().shift(RIGHT * 7)
        
        # Labels
        train_label = Text("TRAINING", font_size=28, color=RED).next_to(train_net, UP)
        infer_label = Text("INFERENCE", font_size=28, color=GREEN).next_to(infer_net, UP)
        
        self.play(
            FadeIn(train_net),
            FadeIn(infer_net),
            Write(train_label),
            Write(infer_label)
        )
        self.wait()
        
        # Training characteristics
        train_features = VGroup(
            Text("✓ Dropout active", font_size=16, color=RED),
            Text("✓ BatchNorm uses batch stats", font_size=16, color=PURPLE),
            Text("✓ Gradients computed", font_size=16, color=YELLOW),
            Text("✓ Weights updated", font_size=16, color=BLUE)
        ).arrange(DOWN, aligned_edge=LEFT, buff=0.15)
        train_features.next_to(train_net, DOWN, buff=0.5)
        
        # Inference characteristics
        infer_features = VGroup(
            Text("✓ Dropout disabled", font_size=16, color=GREEN),
            Text("✓ BatchNorm uses moving avg", font_size=16, color=PURPLE),
            Text("✓ No gradient computation", font_size=16, color=GREY),
            Text("✓ Weights frozen", font_size=16, color=BLUE)
        ).arrange(DOWN, aligned_edge=LEFT, buff=0.15)
        infer_features.next_to(infer_net, DOWN, buff=0.5)
        
        self.play(
            FadeIn(train_features, shift=UP),
            FadeIn(infer_features, shift=UP)
        )
        
        # Animate dropout in training
        train_neurons = train_net.get_neurons_in_layer(1)
        dropped = train_neurons[:2]  # Drop first 2
        
        self.play(
            *[n.animate.set_fill(opacity=0.2) for n in dropped],
            run_time=1
        )
        
        # Show all active in inference
        infer_neurons = infer_net.get_neurons_in_layer(1)
        self.play(
            *[n.animate.set_fill(opacity=0.7) for n in infer_neurons],
            run_time=1
        )
        
        self.wait(3)


class RAGApplicationHint(Scene):
    """Hint at how this relates to the RAG project"""
    
    def construct(self):
        title = Text("Applying to PowerLASCOPF.jl RAG", font_size=42)
        title.to_edge(UP)
        self.play(Write(title))
        
        # Show how NN visualization helps with RAG
        points = VGroup(
            Text("How Neural Network Visualization Helps RAG:", font_size=28, color=YELLOW),
            Text("", font_size=16),  # Spacer
            Text("1. Visual Documentation", font_size=22, color=GREEN),
            Text("   • Generate architecture diagrams automatically", font_size=18, color=GREY),
            Text("   • Include in RAG knowledge base", font_size=18, color=GREY),
            Text("", font_size=16),  # Spacer
            Text("2. Code Understanding", font_size=22, color=BLUE),
            Text("   • Parse code → Generate visualization", font_size=18, color=GREY),
            Text("   • Help users understand ADMM/APP algorithms", font_size=18, color=GREY),
            Text("", font_size=16),  # Spacer
            Text("3. Interactive Queries", font_size=22, color=PURPLE),
            Text("   • 'Show me the network architecture'", font_size=18, color=GREY),
            Text("   • 'How does data flow through the model?'", font_size=18, color=GREY),
            Text("", font_size=16),  # Spacer
            Text("4. Education & Onboarding", font_size=22, color=ORANGE),
            Text("   • New contributors understand faster", font_size=18, color=GREY),
            Text("   • Visual explanations in documentation", font_size=18, color=GREY)
        ).arrange(DOWN, aligned_edge=LEFT, buff=0.15)
        points.scale(0.7).shift(DOWN * 0.3)
        
        self.play(Write(points), run_time=8)
        self.wait(3)


# Main execution
if __name__ == "__main__":
    # This allows running from command line
    # Example: python neural_networks.py
    print("Manim Neural Network Animations")
    print("\nAvailable scenes:")
    print("  1. FluxNetwork - Simple Flux.jl architecture")
    print("  2. PyTorchNetwork - PyTorch with BatchNorm & Dropout")
    print("  3. TensorFlowNetwork - Keras Functional API")
    print("  4. AllNetworksComparison - Side-by-side comparison")
    print("  5. ForwardPropagation - Detailed forward pass")
    print("  6. BatchNormExplanation - BatchNorm explanation")
    print("  7. DropoutVisualization - How dropout works")
    print("  8. ActivationFunctions - Compare activation functions")
    print("  9. ArchitectureEvolution - History of NN architectures")
    print(" 10. ParameterCount - Understanding parameters")
    print(" 11. TrainingVsInference - Training vs inference modes")
    print(" 12. RAGApplicationHint - Connection to RAG systems")
    print("\nUsage:")
    print("  manim -pql neural_networks.py SceneName")
    print("  manim -pqh neural_networks.py SceneName  # High quality")
    print("  manim -pql neural_networks.py -a  # Render all scenes")
