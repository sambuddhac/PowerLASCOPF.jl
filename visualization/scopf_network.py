from manim import *

class SCOPFNetwork(Scene):
    def construct(self):
        # 3Blue1Brown colors
        BLUE_3B1B = "#58C4DD"
        YELLOW_3B1B = "#FFFF00"
        GREEN_3B1B = "#4CBF4C"
        RED_3B1B = "#FF6B6B"
        ORANGE_3B1B = "#FFA500"
        
        # Title
        title = Text("SCOPF: Base Case and Contingency Scenarios", 
                    font_size=32, color=BLUE_3B1B, weight=BOLD)
        title.to_edge(UP)
        self.play(Write(title), run_time=1)
        self.wait(0.5)
        
        def create_network(position, label_text, color, include_all=True):
            """Create a single network instance"""
            group = VGroup()
            
            # Node N1
            node = Circle(radius=0.25, color=color, fill_opacity=0.4, stroke_width=2)
            node.move_to(position)
            node_label = Text("N1", font_size=12, color=color, weight=BOLD)
            node_label.move_to(node)
            group.add(node, node_label)
            
            if include_all:
                # Transmission line T1
                line = Line(
                    start=position,
                    end=position + RIGHT * 1.5,
                    color=color,
                    stroke_width=3
                )
                line_label = Text("T1", font_size=10, color=color)
                line_label.next_to(line, UP, buff=0.1)
                group.add(line, line_label)
                
                # Load D1
                load = Triangle(color=color, fill_opacity=0.4, stroke_width=2)
                load.scale(0.25)
                load.move_to(position + DOWN * 0.8)
                load_label = Text("D1", font_size=10, color=color)
                load_label.next_to(load, DOWN, buff=0.05)
                group.add(load, load_label)
                
                # Generator g1
                gen = Square(color=color, fill_opacity=0.4, stroke_width=2)
                gen.scale(0.25)
                gen.move_to(position + RIGHT * 1.5 + UP * 0.8)
                gen_label = Text("g1", font_size=10, color=color)
                gen_label.move_to(gen)
                group.add(gen, gen_label)
            
            # Scenario label
            scenario_text = Text(label_text, font_size=14, color=color, weight=BOLD)
            scenario_text.next_to(position, LEFT, buff=0.8)
            group.add(scenario_text)
            
            return group
        
        # Base Case (left side)
        base_pos = LEFT * 4 + UP * 1.5
        base_case = create_network(base_pos, "Base\nCase", GREEN_3B1B)
        
        self.play(
            *[Create(mob) if isinstance(mob, (Circle, Line, Triangle, Square)) 
              else Write(mob) for mob in base_case],
            run_time=1.5
        )
        self.wait(0.5)
        
        # Scenario positions (right side, stacked)
        scenario_positions = [
            (RIGHT * 2 + UP * 2.5, "Scenario 1", RED_3B1B, True),
            (RIGHT * 2 + UP * 0.8, "Scenario 2", ORANGE_3B1B, False),
            (RIGHT * 2 + DOWN * 0.8, "Scenario 3", YELLOW_3B1B, True),
            (RIGHT * 2 + DOWN * 2.5, "Scenario 4", BLUE_3B1B, False)
        ]
        
        scenarios = []
        
        for pos, label, color, has_line in scenario_positions:
            scenario = create_network(pos, label, color, include_all=has_line)
            scenarios.append(scenario)
            
            # Arrow from base case to scenario
            arrow = Arrow(
                start=base_pos + RIGHT * 0.5,
                end=pos + LEFT * 0.8,
                color=color,
                stroke_width=2,
                tip_length=0.2
            )
            
            self.play(GrowArrow(arrow), run_time=0.4)
            self.play(
                *[Create(mob) if isinstance(mob, (Circle, Line, Triangle, Square)) 
                  else Write(mob) for mob in scenario],
                run_time=0.8
            )
            
            # Highlight missing component
            if not has_line:
                # Show X mark for outaged line
                x_mark = VGroup(
                    Line(UP * 0.15 + LEFT * 0.15, DOWN * 0.15 + RIGHT * 0.15, color=RED_3B1B, stroke_width=3),
                    Line(UP * 0.15 + RIGHT * 0.15, DOWN * 0.15 + LEFT * 0.15, color=RED_3B1B, stroke_width=3)
                )
                x_mark.move_to(pos + RIGHT * 0.75)
                
                self.play(
                    Create(x_mark),
                    Flash(x_mark, color=RED_3B1B, flash_radius=0.5),
                    run_time=0.5
                )
            
            self.wait(0.3)
        
        self.wait(0.5)
        
        # Add annotation explaining contingencies
        annotation_box = Rectangle(
            width=5, height=1,
            color=BLUE_3B1B,
            fill_opacity=0.1,
            stroke_width=2
        )
        annotation_box.to_edge(DOWN, buff=0.5)
        
        annotation_text = Text(
            "(N-1) Contingency Analysis:\nEach scenario represents one line outage",
            font_size=13,
            color=BLUE_3B1B
        )
        annotation_text.move_to(annotation_box)
        
        self.play(
            Create(annotation_box),
            Write(annotation_text),
            run_time=1
        )
        
        self.wait(2)