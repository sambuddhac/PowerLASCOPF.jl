from manim import *

class LASCOPFStages(Scene):
    def construct(self):
        # 3Blue1Brown colors
        BLUE_3B1B = "#58C4DD"
        YELLOW_3B1B = "#FFFF00"
        GREEN_3B1B = "#4CBF4C"
        RED_3B1B = "#FF6B6B"
        ORANGE_3B1B = "#FFA500"
        PURPLE_3B1B = "#9370DB"
        
        # Title
        title = Text("LASCOPF: Look-Ahead Multi-Stage Optimization", 
                    font_size=30, color=BLUE_3B1B, weight=BOLD)
        title.to_edge(UP)
        self.play(Write(title), run_time=1.2)
        self.wait(0.5)
        
        def create_small_network(position, color, include_all=True):
            """Create a mini network"""
            group = VGroup()
            
            # Node
            node = Circle(radius=0.15, color=color, fill_opacity=0.4, stroke_width=1.5)
            node.move_to(position)
            node_label = Text("N1", font_size=7, color=color, weight=BOLD)
            node_label.move_to(node)
            group.add(node, node_label)
            
            if include_all:
                # Line
                line = Line(
                    start=position,
                    end=position + RIGHT * 0.8,
                    color=color,
                    stroke_width=2
                )
                line_label = Text("T1", font_size=6, color=color)
                line_label.next_to(line, UP, buff=0.05)
                group.add(line, line_label)
                
                # Load
                load = Triangle(color=color, fill_opacity=0.4, stroke_width=1.5)
                load.scale(0.15)
                load.move_to(position + DOWN * 0.5)
                load_label = Text("D1", font_size=6, color=color)
                load_label.next_to(load, DOWN, buff=0.03)
                group.add(load, load_label)
                
                # Generator
                gen = Square(color=color, fill_opacity=0.4, stroke_width=1.5)
                gen.scale(0.12)
                gen.move_to(position + RIGHT * 0.8 + UP * 0.4)
                gen_label = Text("g1", font_size=6, color=color)
                gen_label.move_to(gen)
                group.add(gen, gen_label)
            
            return group
        
        # Stage 1: Base Case (Current time)
        stage1_box = RoundedRectangle(
            width=10, height=1.5,
            corner_radius=0.15,
            color=GREEN_3B1B,
            fill_opacity=0.1,
            stroke_width=3
        )
        stage1_box.shift(UP * 2)
        
        stage1_label = Text("Stage 1: Base Case (τ=0)", font_size=16, color=GREEN_3B1B, weight=BOLD)
        stage1_label.next_to(stage1_box, LEFT, buff=0.3)
        
        self.play(
            Create(stage1_box),
            Write(stage1_label),
            run_time=0.8
        )
        
        # Base case network
        base_network = create_small_network(stage1_box.get_center() + LEFT * 3, GREEN_3B1B)
        
        # Scenarios for stage 1
        s1_positions = [LEFT * 1, RIGHT * 1, RIGHT * 3]
        s1_colors = [RED_3B1B, ORANGE_3B1B, YELLOW_3B1B, BLUE_3B1B]
        s1_include = [True, False, True, False]
        s1_labels = ["Scenario 1", "Scenario 2", "Scenario 3", "Scenario 4"]
        
        self.play(*[Create(mob) if isinstance(mob, (Circle, Line, Triangle, Square)) 
                   else Write(mob) for mob in base_network], run_time=0.8)
        
        for i, (pos, color, include, label) in enumerate(zip(s1_positions + [s1_positions[-1]], 
                                                              s1_colors, s1_include, s1_labels)):
            if i < 3:
                network = create_small_network(stage1_box.get_center() + pos, color, include)
            else:
                network = create_small_network(stage1_box.get_center() + pos + DOWN * 0.6, color, include)
            
            self.play(*[FadeIn(mob, scale=0.7) if isinstance(mob, (Circle, Line, Triangle, Square)) 
                       else Write(mob) for mob in network], run_time=0.4)
        
        self.wait(0.5)
        
        # Stage 2: Look-ahead Stage 1 (τ=1)
        stage2_box = RoundedRectangle(
            width=10, height=1.5,
            corner_radius=0.15,
            color=PURPLE_3B1B,
            fill_opacity=0.1,
            stroke_width=3
        )
        stage2_box.shift(UP * 0)
        
        stage2_label = Text("Stage 2: Look-Ahead τ=1", font_size=14, color=PURPLE_3B1B, weight=BOLD)
        stage2_label.next_to(stage2_box, LEFT, buff=0.3)
        
        # Arrow connecting stages
        arrow_1_2 = Arrow(
            start=stage1_box.get_bottom(),
            end=stage2_box.get_top(),
            color=PURPLE_3B1B,
            stroke_width=3,
            tip_length=0.25
        )
        
        self.play(GrowArrow(arrow_1_2), run_time=0.6)
        self.play(
            Create(stage2_box),
            Write(stage2_label),
            run_time=0.7
        )
        
        # Networks for stage 2 (same structure, different colors)
        base2_network = create_small_network(stage2_box.get_center() + LEFT * 3, PURPLE_3B1B)
        self.play(*[FadeIn(mob, scale=0.7) if isinstance(mob, (Circle, Line, Triangle, Square)) 
                   else Write(mob) for mob in base2_network], run_time=0.6)
        
        for i, (pos, include) in enumerate(zip(s1_positions + [s1_positions[-1]], s1_include)):
            if i < 3:
                network = create_small_network(stage2_box.get_center() + pos, PURPLE_3B1B, include)
            else:
                network = create_small_network(stage2_box.get_center() + pos + DOWN * 0.6, PURPLE_3B1B, include)
            self.play(*[FadeIn(mob, scale=0.6) for mob in network], run_time=0.3)
        
        self.wait(0.3)
        
        # Stage 3: Look-ahead Stage 2 (τ=2)
        stage3_box = RoundedRectangle(
            width=10, height=1.5,
            corner_radius=0.15,
            color=ORANGE_3B1B,
            fill_opacity=0.1,
            stroke_width=3
        )
        stage3_box.shift(DOWN * 2)
        
        stage3_label = Text("Stage 3: Look-Ahead τ=ΓRND", font_size=13, color=ORANGE_3B1B, weight=BOLD)
        stage3_label.next_to(stage3_box, LEFT, buff=0.3)
        
        # Arrow connecting stages
        arrow_2_3 = Arrow(
            start=stage2_box.get_bottom(),
            end=stage3_box.get_top(),
            color=ORANGE_3B1B,
            stroke_width=3,
            tip_length=0.25
        )
        
        # Dots indicating more stages
        dots = Text("...", font_size=36, color=WHITE)
        dots.move_to((stage2_box.get_bottom() + stage3_box.get_top()) / 2)
        
        self.play(Write(dots), run_time=0.5)
        self.play(GrowArrow(arrow_2_3), run_time=0.6)
        self.play(
            Create(stage3_box),
            Write(stage3_label),
            run_time=0.7
        )
        
        # Networks for stage 3
        base3_network = create_small_network(stage3_box.get_center() + LEFT * 3, ORANGE_3B1B)
        self.play(*[FadeIn(mob, scale=0.7) for mob in base3_network], run_time=0.6)
        
        for i, (pos, include) in enumerate(zip(s1_positions + [s1_positions[-1]], s1_include)):
            if i < 3:
                network = create_small_network(stage3_box.get_center() + pos, ORANGE_3B1B, include)
            else:
                network = create_small_network(stage3_box.get_center() + pos + DOWN * 0.6, ORANGE_3B1B, include)
            self.play(*[FadeIn(mob, scale=0.6) for mob in network], run_time=0.3)
        
        self.wait(0.5)
        
        # Highlight the look-ahead window
        lookahead_brace = Brace(
            VGroup(stage1_box, stage2_box, stage3_box),
            direction=RIGHT,
            color=BLUE_3B1B
        )
        
        lookahead_label = Text("Look-Ahead\nWindow", font_size=14, color=BLUE_3B1B, weight=BOLD)
        lookahead_label.next_to(lookahead_brace, RIGHT, buff=0.2)
        
        self.play(
            GrowFromCenter(lookahead_brace),
            Write(lookahead_label),
            run_time=1
        )
        
        self.wait(0.5)
        
        # Add annotation
        annotation_box = Rectangle(
            width=11, height=0.8,
            color=BLUE_3B1B,
            fill_opacity=0.1,
            stroke_width=2
        )
        annotation_box.to_edge(DOWN, buff=0.3)
        
        annotation_text = Text(
            "Multi-stage optimization: Ensures post-contingency restoration over ΓRND intervals",
            font_size=12,
            color=BLUE_3B1B
        )
        annotation_text.move_to(annotation_box)
        
        self.play(
            Create(annotation_box),
            Write(annotation_text),
            run_time=1
        )
        
        self.wait(2)