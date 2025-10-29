from manim import *

class ThermalRatings(Scene):
    def construct(self):
        # 3Blue1Brown colors
        BLUE_3B1B = "#58C4DD"
        YELLOW_3B1B = "#FFFF00"
        GREEN_3B1B = "#4CBF4C"
        RED_3B1B = "#FF6B6B"
        ORANGE_3B1B = "#FFA500"
        
        # Title
        title = Text("Transmission Line Thermal Ratings", 
                    font_size=32, color=BLUE_3B1B, weight=BOLD)
        title.to_edge(UP)
        self.play(Write(title), run_time=1)
        self.wait(0.5)
        
        # Two graphs side by side
        # Left: Temperature vs Time
        temp_axes = Axes(
            x_range=[0, 10, 2],
            y_range=[0, 150, 50],
            x_length=5,
            y_length=4,
            axis_config={"color": WHITE, "stroke_width": 2},
            x_axis_config={"numbers_to_include": [0, 5, 10]},
            y_axis_config={"numbers_to_include": [0, 50, 100, 150]}
        )
        temp_axes.shift(LEFT * 3 + DOWN * 0.5)
        
        temp_x_label = Text("Time (s)", font_size=16, color=WHITE)
        temp_x_label.next_to(temp_axes, DOWN, buff=0.3)
        
        temp_y_label = Text("Line\nTemperature", font_size=14, color=WHITE)
        temp_y_label.next_to(temp_axes, LEFT, buff=0.3)
        
        temp_title = Text("Temperature Evolution", font_size=18, color=BLUE_3B1B, weight=BOLD)
        temp_title.next_to(temp_axes, UP, buff=0.4)
        
        self.play(
            Create(temp_axes),
            Write(temp_x_label),
            Write(temp_y_label),
            Write(temp_title),
            run_time=1
        )
        self.wait(0.3)
        
        # Maximum allowed temperature line
        max_temp_line = DashedLine(
            start=temp_axes.c2p(0, 130),
            end=temp_axes.c2p(10, 130),
            color=RED_3B1B,
            stroke_width=3,
            dash_length=0.15
        )
        
        max_temp_label = Text("Maximum Allowed\nTemperature", font_size=11, color=RED_3B1B)
        max_temp_label.next_to(temp_axes.c2p(10, 130), RIGHT, buff=0.1)
        
        self.play(
            Create(max_temp_line),
            Write(max_temp_label),
            run_time=0.8
        )
        self.wait(0.3)
        
        # Short-term temperature curve
        short_term_curve = temp_axes.plot(
            lambda x: 50 + 90 * (1 - np.exp(-0.8 * x)),
            x_range=[0, 10],
            color=ORANGE_3B1B,
            stroke_width=4
        )
        
        short_term_label = Text("Temperature Curve\nfor Short-Term Rating", 
                               font_size=10, color=ORANGE_3B1B)
        short_term_label.next_to(temp_axes.c2p(5, 100), UP, buff=0.1)
        
        self.play(
            Create(short_term_curve),
            run_time=2,
            rate_func=linear
        )
        self.play(Write(short_term_label), run_time=0.6)
        self.wait(0.3)
        
        # Long-term temperature curve
        long_term_curve = temp_axes.plot(
            lambda x: 50 + 60 * (1 - np.exp(-0.5 * x)),
            x_range=[0, 10],
            color=GREEN_3B1B,
            stroke_width=4
        )
        
        long_term_label = Text("Temperature Curve for\nLong-Term Rating", 
                              font_size=10, color=GREEN_3B1B)
        long_term_label.next_to(temp_axes.c2p(7, 80), DOWN, buff=0.1)
        
        self.play(
            Create(long_term_curve),
            run_time=2,
            rate_func=linear
        )
        self.play(Write(long_term_label), run_time=0.6)
        
        self.wait(0.5)
        
        # Right: Power Flow/Current Flow vs Time
        power_axes = Axes(
            x_range=[0, 10, 2],
            y_range=[0, 150, 50],
            x_length=5,
            y_length=4,
            axis_config={"color": WHITE, "stroke_width": 2},
            x_axis_config={"numbers_to_include": [0, 5, 10]},
            y_axis_config={"numbers_to_include": [0, 50, 100, 150]}
        )
        power_axes.shift(RIGHT * 3 + DOWN * 0.5)
        
        power_x_label = Text("Time (s)", font_size=16, color=WHITE)
        power_x_label.next_to(power_axes, DOWN, buff=0.3)
        
        power_y_label = Text("Line Power\nFlow/Current\nFlow", font_size=12, color=WHITE)
        power_y_label.next_to(power_axes, LEFT, buff=0.3)
        
        power_title = Text("Power Flow Limits", font_size=18, color=BLUE_3B1B, weight=BOLD)
        power_title.next_to(power_axes, UP, buff=0.4)
        
        self.play(
            Create(power_axes),
            Write(power_x_label),
            Write(power_y_label),
            Write(power_title),
            run_time=1
        )
        self.wait(0.3)
        
        # Short-term rating (higher)
        short_term_rating = DashedLine(
            start=power_axes.c2p(0, 120),
            end=power_axes.c2p(10, 120),
            color=ORANGE_3B1B,
            stroke_width=3,
            dash_length=0.15
        )
        
        short_label = Text("Short-Term\nRating", font_size=10, color=ORANGE_3B1B)
        short_label.next_to(power_axes.c2p(10, 120), RIGHT, buff=0.1)
        
        self.play(
            Create(short_term_rating),
            Write(short_label),
            run_time=0.7
        )
        
        # Long-term rating (lower)
        long_term_rating = DashedLine(
            start=power_axes.c2p(0, 80),
            end=power_axes.c2p(10, 80),
            color=GREEN_3B1B,
            stroke_width=3,
            dash_length=0.15
        )
        
        long_label = Text("Long-Term\nRating", font_size=10, color=GREEN_3B1B)
        long_label.next_to(power_axes.c2p(10, 80), RIGHT, buff=0.1)
        
        self.play(
            Create(long_term_rating),
            Write(long_label),
            run_time=0.7
        )
        
        self.wait(0.3)
        
        # Power flow after contingency
        contingency_time = 2
        power_flow = VGroup()
        
        # High flow during contingency
        high_flow = power_axes.plot(
            lambda x: 120 if x >= contingency_time else 80,
            x_range=[0, 10],
            color=RED_3B1B,
            stroke_width=4,
            discontinuities=[contingency_time]
        )
        
        self.play(Create(high_flow), run_time=2)
        
        # Show allowed duration
        duration_bracket = BraceBetweenPoints(
            power_axes.c2p(contingency_time, 0),
            power_axes.c2p(contingency_time + 3, 0),
            direction=DOWN,
            color=YELLOW_3B1B
        )
        
        duration_label = Text("Maximum Duration Allowed\nfor Maximum Rated Short-Term Flow", 
                             font_size=9, color=YELLOW_3B1B)
        duration_label.next_to(duration_bracket, DOWN, buff=0.1)
        
        self.play(
            GrowFromCenter(duration_bracket),
            Write(duration_label),
            run_time=1
        )
        
        # Mark contingency event
        contingency_arrow = Arrow(
            start=power_axes.c2p(contingency_time, 140),
            end=power_axes.c2p(contingency_time, 125),
            color=RED_3B1B,
            stroke_width=3,
            tip_length=0.2
        )
        
        contingency_text = Text("Contingency\nOccurs", font_size=11, color=RED_3B1B, weight=BOLD)
        contingency_text.next_to(contingency_arrow, UP, buff=0.1)
        
        self.play(
            GrowArrow(contingency_arrow),
            Write(contingency_text),
            Flash(power_axes.c2p(contingency_time, 120), color=RED_3B1B, flash_radius=0.5),
            run_time=0.8
        )
        
        self.wait(0.5)
        
        # Add key equation at bottom
        equation_box = Rectangle(
            width=11, height=0.9,
            color=BLUE_3B1B,
            fill_opacity=0.1,
            stroke_width=2
        )
        equation_box.to_edge(DOWN, buff=0.3)
        
        equation = MathTex(
            r"\psi_{T_r}(t) = \psi_{\text{amb}} + \frac{\alpha'}{\beta'}(P_{T_r}(t))^2 < \psi_{T_r}^{\max}",
            font_size=24,
            color=BLUE_3B1B
        )
        equation.move_to(equation_box)
        
        self.play(
            Create(equation_box),
            Write(equation),
            run_time=1
        )
        
        self.wait(2)