from manim import *

class TemporalExecutionFlow(Scene):
    def construct(self):
        # 3Blue1Brown colors
        BLUE_3B1B = "#58C4DD"
        YELLOW_3B1B = "#FFFF00"
        GREEN_3B1B = "#4CBF4C"
        RED_3B1B = "#FF6B6B"
        ORANGE_3B1B = "#FFA500"
        
        # Title
        title = Text("Temporal Execution Flow", font_size=32, color=BLUE_3B1B)
        title.to_edge(UP)
        self.play(Write(title), run_time=1)
        self.wait(0.5)
        
        # Timeline
        timeline = Line(LEFT * 6, RIGHT * 6, color=WHITE, stroke_width=2)
        timeline.shift(DOWN * 0.5)
        self.play(Create(timeline), run_time=0.8)
        
        # Time markers
        time_positions = np.linspace(-5, 5, 7)
        time_labels = ["t=0", "5 min", "10 min", "15 min", "...", "24 hr", "DAM"]
        
        for pos, label in zip(time_positions, time_labels):
            tick = Line(UP * 0.15, DOWN * 0.15, color=WHITE)
            tick.move_to(timeline.get_center() + RIGHT * pos)
            
            time_text = Text(label, font_size=10, color=WHITE)
            time_text.next_to(tick, DOWN, buff=0.15)
            
            self.play(
                Create(tick),
                FadeIn(time_text, scale=0.5),
                run_time=0.2
            )
        
        self.wait(0.5)
        
        # RTM operations (frequent - every 5 minutes)
        rtm_y = UP * 1.5
        
        for i in range(4):
            rtm_box = RoundedRectangle(
                width=0.8, height=0.6,
                corner_radius=0.1,
                color=RED_3B1B,
                fill_opacity=0.3,
                stroke_width=2
            )
            rtm_box.move_to(timeline.get_center() + RIGHT * time_positions[i] + rtm_y)
            
            rtm_label = Text("RTM", font_size=10, color=RED_3B1B, weight=BOLD)
            rtm_label.move_to(rtm_box)
            
            # Action arrow
            action_arrow = Arrow(
                start=rtm_box.get_bottom(),
                end=timeline.get_center() + RIGHT * time_positions[i] + UP * 0.2,
                color=RED_3B1B,
                stroke_width=2,
                tip_length=0.15
            )
            
            self.play(
                Create(rtm_box),
                Write(rtm_label),
                Create(action_arrow),
                run_time=0.4
            )
        
        # RTM label
        rtm_main = Text("Real-Time Market (Every 5 min)", font_size=14, color=RED_3B1B)
        rtm_main.move_to(rtm_y + RIGHT * 3)
        self.play(Write(rtm_main), run_time=0.6)
        
        self.wait(0.5)
        
        # Reward collection (upward arrows from environment)
        for i in range(4):
            reward_arrow = Arrow(
                start=timeline.get_center() + RIGHT * time_positions[i] + DOWN * 0.3,
                end=timeline.get_center() + RIGHT * time_positions[i] + rtm_y + DOWN * 0.4,
                color=GREEN_3B1B,
                stroke_width=2,
                tip_length=0.15
            )
            
            reward_label = Text("R", font_size=10, color=GREEN_3B1B, weight=BOLD)
            reward_label.next_to(reward_arrow, LEFT, buff=0.1)
            
            self.play(
                Create(reward_arrow),
                Write(reward_label),
                run_time=0.3
            )
        
        # Reward collection label
        reward_main = Text("Rewards (Every 5 min)", font_size=12, color=GREEN_3B1B)
        reward_main.move_to(DOWN * 1.5 + RIGHT * 0)
        self.play(Write(reward_main), run_time=0.6)
        
        self.wait(0.5)
        
        # DAM operation (once per day)
        dam_y = UP * 2.8
        dam_box = RoundedRectangle(
            width=5, height=0.8,
            corner_radius=0.15,
            color=YELLOW_3B1B,
            fill_opacity=0.25,
            stroke_width=3
        )
        dam_box.move_to(dam_y + RIGHT * 1)
        
        dam_label = Text("Day-Ahead Market (DAM) Scheduler", font_size=14, color=YELLOW_3B1B, weight=BOLD)
        dam_label.move_to(dam_box)
        
        self.play(
            Create(dam_box),
            Write(dam_label),
            run_time=1
        )
        
        # DAM decision arrow (spans entire day)
        dam_arrow = CurvedDoubleArrow(
            start_point=dam_box.get_bottom() + LEFT * 2,
            end_point=timeline.get_center() + RIGHT * 4.5 + UP * 0.3,
            color=YELLOW_3B1B,
            stroke_width=3,
            tip_length=0.2,
            angle=-TAU/8
        )
        
        dam_action_label = Text("24-hour Decisions", font_size=11, color=YELLOW_3B1B)
        dam_action_label.next_to(dam_arrow, UP, buff=0.1)
        
        self.play(Create(dam_arrow), run_time=1.2)
        self.play(Write(dam_action_label), run_time=0.6)
        
        self.wait(0.5)
        
        # Cumulative reward for DAM
        cumulative_arrow = Arrow(
            start=timeline.get_center() + RIGHT * 4.5 + DOWN * 0.5,
            end=dam_box.get_right() + DOWN * 0.2,
            color=ORANGE_3B1B,
            stroke_width=3,
            tip_length=0.25
        )
        
        cumulative_label = Text("Cumulative\nReward", font_size=11, color=ORANGE_3B1B, weight=BOLD)
        cumulative_label.next_to(cumulative_arrow, RIGHT, buff=0.15)
        
        self.play(Create(cumulative_arrow), run_time=0.8)
        self.play(Write(cumulative_label), run_time=0.6)
        
        self.wait(0.5)
        
        # Learning indication
        learning_box = RoundedRectangle(
            width=2.5, height=0.6,
            corner_radius=0.1,
            color=BLUE_3B1B,
            fill_opacity=0.2,
            stroke_width=2
        )
        learning_box.shift(DOWN * 2.5 + RIGHT * 4)
        
        learning_text = Text("Learning\nfrom Experience", font_size=11, color=BLUE_3B1B, weight=BOLD)
        learning_text.move_to(learning_box)
        
        # Arrow from cumulative to learning
        learn_arrow = Arrow(
            start=cumulative_arrow.get_end() + DOWN * 0.5,
            end=learning_box.get_top(),
            color=BLUE_3B1B,
            stroke_width=2,
            tip_length=0.2
        )
        
        self.play(Create(learning_box), Write(learning_text), run_time=0.8)
        self.play(Create(learn_arrow), run_time=0.6)
        
        self.wait(0.5)
        
        # Feedback loop back to DAM
        feedback_arc = CurvedArrow(
            start_point=learning_box.get_left() + LEFT * 0.1,
            end_point=dam_box.get_bottom() + DOWN * 0.3 + RIGHT * 1.5,
            color=BLUE_3B1B,
            stroke_width=2,
            tip_length=0.2,
            angle=TAU/4
        )
        
        feedback_label = Text("Policy\nUpdate", font_size=10, color=BLUE_3B1B)
        feedback_label.next_to(feedback_arc, LEFT, buff=0.2)
        
        self.play(Create(feedback_arc), run_time=1.2)
        self.play(Write(feedback_label), run_time=0.6)
        
        self.wait(2)