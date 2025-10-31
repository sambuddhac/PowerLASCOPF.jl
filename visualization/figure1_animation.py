from manim import *

class SmartMarketLearning(Scene):
    def construct(self):
        # 3Blue1Brown colors
        BLUE_3B1B = "#58C4DD"
        YELLOW_3B1B = "#FFFF00"
        GREEN_3B1B = "#4CBF4C"
        RED_3B1B = "#FF6B6B"
        ORANGE_3B1B = "#FFA500"
        
        # Title
        title = Text("Smart Electricity Market with Learning Ability", font_size=32, color=BLUE_3B1B)
        title.to_edge(UP)
        self.play(Write(title), run_time=1)
        self.wait(0.5)
        
        # AGENT (Yellow ribbon - DAM and RTM Scheduler)
        agent_box = RoundedRectangle(
            width=4, height=2.5, corner_radius=0.2,
            color=YELLOW_3B1B, fill_opacity=0.2, stroke_width=3
        )
        agent_box.shift(UP * 1.5 + LEFT * 3.5)
        
        agent_label = Text("Agent", font_size=24, color=YELLOW_3B1B, weight=BOLD)
        agent_label.next_to(agent_box, UP, buff=0.2)
        
        dam_text = Text("DAM Scheduler", font_size=16, color=YELLOW_3B1B)
        dam_text.move_to(agent_box.get_center() + UP * 0.5)
        
        rtm_text = Text("RTM Scheduler", font_size=16, color=YELLOW_3B1B)
        rtm_text.move_to(agent_box.get_center() + DOWN * 0.5)
        
        self.play(
            Create(agent_box),
            Write(agent_label),
            run_time=1
        )
        self.play(
            Write(dam_text),
            Write(rtm_text),
            run_time=0.8
        )
        self.wait(0.5)
        
        # ENVIRONMENT (Green box - BTM, FTM, Network)
        env_box = RoundedRectangle(
            width=4, height=2.5, corner_radius=0.2,
            color=GREEN_3B1B, fill_opacity=0.2, stroke_width=3
        )
        env_box.shift(UP * 1.5 + RIGHT * 3.5)
        
        env_label = Text("Environment", font_size=24, color=GREEN_3B1B, weight=BOLD)
        env_label.next_to(env_box, UP, buff=0.2)
        
        btm_text = Text("BTM Resources", font_size=14, color=GREEN_3B1B)
        btm_text.move_to(env_box.get_center() + UP * 0.6)
        
        ftm_text = Text("FTM Resources", font_size=14, color=GREEN_3B1B)
        ftm_text.move_to(env_box.get_center())
        
        network_text = Text("Power Network", font_size=14, color=GREEN_3B1B)
        network_text.move_to(env_box.get_center() + DOWN * 0.6)
        
        self.play(
            Create(env_box),
            Write(env_label),
            run_time=1
        )
        self.play(
            Write(btm_text),
            Write(ftm_text),
            Write(network_text),
            run_time=0.8
        )
        self.wait(0.5)
        
        # ACTIONS (Blue arrows from Agent to Environment)
        action_arrow = CurvedArrow(
            start_point=agent_box.get_right() + RIGHT * 0.1,
            end_point=env_box.get_left() + LEFT * 0.1,
            color=BLUE_3B1B,
            stroke_width=4,
            tip_length=0.3
        )
        
        action_label = Text("Actions\n(DAM/RTM Decisions)", font_size=12, color=BLUE_3B1B)
        action_label.next_to(action_arrow, UP, buff=0.2)
        
        self.play(Create(action_arrow), run_time=0.8)
        self.play(FadeIn(action_label, scale=0.8), run_time=0.6)
        self.wait(0.3)
        
        # REWARDS (Red curved arrow back)
        reward_arrow = CurvedArrow(
            start_point=env_box.get_left() + LEFT * 0.1 + DOWN * 0.8,
            end_point=agent_box.get_right() + RIGHT * 0.1 + DOWN * 0.8,
            color=RED_3B1B,
            stroke_width=4,
            tip_length=0.3,
            angle=-TAU/6
        )
        
        reward_label = Text("Rewards\n(Social Welfare - Risk)", font_size=12, color=RED_3B1B)
        reward_label.next_to(reward_arrow, DOWN, buff=0.2)
        
        self.play(Create(reward_arrow), run_time=0.8)
        self.play(FadeIn(reward_label, scale=0.8), run_time=0.6)
        self.wait(0.3)
        
        # STATE boxes below
        state_box1 = RoundedRectangle(
            width=3, height=1.2, corner_radius=0.15,
            color=ORANGE_3B1B, fill_opacity=0.15, stroke_width=2
        )
        state_box1.shift(DOWN * 2 + LEFT * 3.5)
        
        state1_label = Text("Design Parameters", font_size=14, color=ORANGE_3B1B)
        state1_label.move_to(state_box1)
        
        state_box2 = RoundedRectangle(
            width=3, height=1.2, corner_radius=0.15,
            color=ORANGE_3B1B, fill_opacity=0.15, stroke_width=2
        )
        state_box2.shift(DOWN * 2 + RIGHT * 0.5)
        
        state2_label = Text("Operational\nParameters", font_size=14, color=ORANGE_3B1B)
        state2_label.move_to(state_box2)
        
        state_box3 = RoundedRectangle(
            width=2, height=1.2, corner_radius=0.15,
            color=ORANGE_3B1B, fill_opacity=0.15, stroke_width=2
        )
        state_box3.shift(DOWN * 2 + RIGHT * 4.5)
        
        state3_label = Text("Forecast", font_size=14, color=ORANGE_3B1B)
        state3_label.move_to(state_box3)
        
        state_main_label = Text("State of the System", font_size=18, color=ORANGE_3B1B, weight=BOLD)
        state_main_label.move_to(DOWN * 3.2)
        
        self.play(
            Create(state_box1),
            Create(state_box2),
            Create(state_box3),
            run_time=0.8
        )
        self.play(
            Write(state1_label),
            Write(state2_label),
            Write(state3_label),
            run_time=0.8
        )
        self.play(Write(state_main_label), run_time=0.6)
        self.wait(0.5)
        
        # State transition arrows
        state_arrow1 = Arrow(
            start=state_box1.get_top(),
            end=agent_box.get_bottom() + LEFT * 1,
            color=ORANGE_3B1B,
            stroke_width=2,
            tip_length=0.2
        )
        
        state_arrow2 = Arrow(
            start=state_box2.get_top(),
            end=env_box.get_bottom(),
            color=ORANGE_3B1B,
            stroke_width=2,
            tip_length=0.2
        )
        
        self.play(
            Create(state_arrow1),
            Create(state_arrow2),
            run_time=0.6
        )
        
        # Risk mitigation boxes
        risk_box = RoundedRectangle(
            width=2.5, height=0.8, corner_radius=0.1,
            color=RED_3B1B, fill_opacity=0.1, stroke_width=2
        )
        risk_box.shift(UP * 0.2 + LEFT * 0.5)
        
        risk_text = Text("System Risk\nMitigation", font_size=12, color=RED_3B1B)
        risk_text.move_to(risk_box)
        
        self.play(Create(risk_box), Write(risk_text), run_time=0.6)
        self.wait(0.5)

        # ZOOM OUT
        all_objects = Group(*self.mobjects)
        self.play(all_objects.animate.scale(0.75).move_to(ORIGIN), run_time=1.5)
        self.wait(0.5)
        
        # Learning cycle indication
        learning_arc = Arc(
            radius=2.5,
            start_angle=PI/4,
            angle=3*PI/2,
            color=YELLOW_3B1B,
            stroke_width=3
        )
        learning_arc.shift(UP * 0.5)
        
        learning_label = Text("Learning Loop", font_size=16, color=YELLOW_3B1B, weight=BOLD)
        learning_label.move_to(UP * 0.3)
        
        self.play(Create(learning_arc), run_time=1.5)
        self.play(FadeIn(learning_label, scale=0.8), run_time=0.6)
        
        self.wait(2)