from manim import *

class LASCOPFTimeline(Scene):
    def construct(self):
        # Colors matching the diagram - LIGHTER versions for black background
        RED_DASH = "#FF6B6B"
        BROWN = "#CD853F"
        BLUE = "#87CEEB"  # Light blue
        ORANGE = "#FFA500"  # Lighter orange
        GREEN = "#90EE90"  # Light green
        
        # 1. RED DASHED CIRCLE - "Present" (overlaps with brown) - MUCH LARGER (3x)
        red_pos = LEFT * 5.5
        red_circle = DashedVMobject(Circle(radius=1.8, color=RED_DASH, fill_opacity=0.03, stroke_width=2), num_dashes=25)
        red_circle.move_to(red_pos)
        
        red_label = Text("Present", font_size=26, color=RED_DASH)
        red_label.next_to(red_circle, UP, buff=0.6)
        
        red_time = MathTex(r"\tau, c=0", font_size=22, color=WHITE)
        red_time.next_to(red_circle, DOWN, buff=1.9)
        
        self.play(Create(red_circle), run_time=0.8)
        self.play(Write(red_label), Write(red_time), run_time=0.8)
        self.wait(0.5)
        
        # 2. BROWN CIRCLE - "τ - 1, c=0" (overlaps with red) - MUCH LARGER (3x)
        brown_pos = LEFT * 2.5
        brown_circle = Circle(radius=1.8, color=BROWN, fill_opacity=0.08, stroke_width=3)
        brown_circle.move_to(brown_pos)
        
        brown_label = Text("Forthcoming Interval", font_size=26, color=BROWN)
        brown_label.next_to(brown_circle, UP, buff=0.6)
        
        brown_time = MathTex(r"\tau - 1, c=0", font_size=22, color=WHITE)
        brown_time.next_to(brown_circle, DOWN, buff=1.9)
        
        self.play(GrowFromCenter(brown_circle), run_time=0.8)
        self.play(Write(brown_label), Write(brown_time), run_time=0.8)
        self.wait(0.5)
        
        # Add pair of single-headed white arrows between red and brown circles - BIGGER
        # Arrows at intersection pointing right (toward brown)
        intersection_center = (red_pos + brown_pos) / 2
        arrow_offset = 0.3  # Increased offset for bigger coverage
        
        for offset_mult in [-1, 1]:
            arrow_pos = intersection_center + UP * offset_mult * arrow_offset
            arrow = Arrow(
                start=arrow_pos + LEFT * 0.6,  # Longer arrow
                end=arrow_pos + RIGHT * 0.6,
                color=WHITE,
                stroke_width=3,  # Thicker
                tip_length=0.25  # Bigger arrowhead
            )
            self.play(GrowArrow(arrow), run_time=0.4)
        
        self.wait(0.5)
        
        # 3. THREE CHAINS radiating from brown circle at different angles
        chain_configs = [
            {"angle_deg": 45, "c_label": r"C=0", "direction": "up-right"},
            {"angle_deg": 0, "c_label": r"C=C", "direction": "horizontal"},
            {"angle_deg": -45, "c_label": r"c=|\mathcal{L}|", "direction": "down-right"}
        ]
        
        # Circle sequence in each chain
        circle_sequence = [
            ("ED", BLUE),
            ("ED", BLUE),
            ("ED", BLUE),
            ("OPF", ORANGE),
            ("OPF", ORANGE),
            ("OPF", ORANGE),
            ("SCOPF", GREEN)
        ]
        
        time_sequence = [
            r"\tau = 1",
            r"\tau = 2",
            r"\tau = \Gamma_{RND} - 1",
            r"\tau = \Gamma_{RND}",
            r"\tau = \Gamma_{RND} + 1",
            r"\tau = \Gamma_{MRD} - 1",
            r"\tau = \Gamma_{MRD}"
        ]
        
        all_circles = []
        all_ed_circles = []
        first_circles_in_chains = []
        
        for chain_idx, config in enumerate(chain_configs):
            angle_rad = config["angle_deg"] * DEGREES
            
            chain_circles = []
            
            for i, (label, color) in enumerate(circle_sequence):
                brown_radius = 1.8
                circle_radius = 0.45
                overlap_distance = brown_radius + circle_radius - 0.5
                
                distance_from_brown = overlap_distance + i * 0.85
                
                x_offset = distance_from_brown * np.cos(angle_rad)
                y_offset = distance_from_brown * np.sin(angle_rad)
                
                circle_pos = brown_pos + RIGHT * x_offset + UP * y_offset
                
                circle = Circle(radius=0.45, color=color, fill_opacity=0.15, stroke_width=3)
                circle.move_to(circle_pos)
                chain_circles.append(circle)
                
                if chain_idx == 0:
                    text_label = Text(label, font_size=20, color=color, weight=BOLD)
                    text_label.next_to(circle, UP, buff=0.25)
                    
                    time_label = MathTex(time_sequence[i], font_size=18, color=WHITE)
                    time_label.next_to(circle, DOWN, buff=0.45)
                    
                    self.play(GrowFromCenter(circle), run_time=0.4)
                    self.play(Write(text_label), Write(time_label), run_time=0.4)
                else:
                    self.play(GrowFromCenter(circle), run_time=0.3)
                
                if i <= 2:
                    all_ed_circles.append(circle)
                
                if i == 0:
                    first_circles_in_chains.append(circle)
                
                if i > 0:
                    prev_circle = chain_circles[i - 1]
                    intersection_pos = (prev_circle.get_center() + circle.get_center()) / 2
                    perp_angle = angle_rad + PI / 2
                    perp_offset = 0.15
                    
                    for offset_mult in [-1, 1]:
                        arrow_center = intersection_pos + offset_mult * perp_offset * np.array([np.cos(perp_angle), np.sin(perp_angle), 0])
                        arrow_length = 0.3
                        arrow_start = arrow_center - arrow_length / 2 * np.array([np.cos(angle_rad), np.sin(angle_rad), 0])
                        arrow_end = arrow_center + arrow_length / 2 * np.array([np.cos(angle_rad), np.sin(angle_rad), 0])
                        
                        double_arrow = DoubleArrow(
                            start=arrow_start,
                            end=arrow_end,
                            color=WHITE,
                            stroke_width=2.5,
                            buff=0,
                            max_tip_length_to_length_ratio=0.25
                        )
                        
                        self.play(GrowArrow(double_arrow), run_time=0.25)
                
                self.wait(0.1)
            
            all_circles.append(chain_circles)
            
            last_circle_pos = chain_circles[-1].get_center()
            brace_pos = last_circle_pos + RIGHT * 0.8
            
            brace = MathTex(r"\}", font_size=60, color=GREEN)
            brace.move_to(brace_pos)
            
            brace_label = MathTex(config["c_label"], font_size=22, color=GREEN)
            brace_label.next_to(brace, RIGHT, buff=0.2)
            
            self.play(Write(brace), Write(brace_label), run_time=0.5)
            self.wait(0.2)
        
        # Add pairs of double-headed arrows from brown to first circles BEFORE zoom
        for first_circle in first_circles_in_chains:
            intersection_pos = (brown_circle.get_center() + first_circle.get_center()) / 2
            direction_vector = first_circle.get_center() - brown_circle.get_center()
            chain_angle = np.arctan2(direction_vector[1], direction_vector[0])
            perp_angle = chain_angle + PI / 2
            perp_offset = 0.15
            
            for offset_mult in [-1, 1]:
                arrow_center = intersection_pos + offset_mult * perp_offset * np.array([np.cos(perp_angle), np.sin(perp_angle), 0])
                arrow_length = 0.3
                arrow_start = arrow_center - arrow_length / 2 * np.array([np.cos(chain_angle), np.sin(chain_angle), 0])
                arrow_end = arrow_center + arrow_length / 2 * np.array([np.cos(chain_angle), np.sin(chain_angle), 0])
                
                double_arrow = DoubleArrow(
                    start=arrow_start,
                    end=arrow_end,
                    color=WHITE,
                    stroke_width=2.5,
                    buff=0,
                    max_tip_length_to_length_ratio=0.25
                )
                
                self.play(GrowArrow(double_arrow), run_time=0.25)
        
        self.wait(0.5)
        
        # ZOOM OUT
        all_objects = Group(*self.mobjects)
        self.play(all_objects.animate.scale(0.75).move_to(ORIGIN), run_time=1.5)
        self.wait(0.5)
        
        # 4. Equation
        equation = MathTex(
            r"E_{\Gamma}^{(\omega)}[\psi]+\cdots<\psi_{T_r}^{\max}",
            font_size=14,
            color=BLUE
        )
        equation.move_to(brown_pos)
        
        self.play(FadeIn(equation, scale=0.8), run_time=1)
        self.wait(0.5)
        
        for ed_circle in all_ed_circles:
            arrow = CurvedArrow(
                start_point=brown_circle.get_center(),
                end_point=ed_circle.get_center(),
                color=BLUE,
                stroke_width=2.5,
                angle=-TAU/8,
                tip_length=0.15
            )
            
            eq_copy = equation.copy()
            self.play(Transform(eq_copy, arrow), run_time=0.8)
            self.add(arrow)
            self.remove(eq_copy)
            self.wait(0.2)
        
        self.wait(2)