축 정의 X=0,Y=1,Z=2,T=3,A=4,B=5,C=6,D=7축 정의 x=0,y=1,z=2,t=3,a=4,b=5,c=6,d=7전역 정수I(100),I0,I1,I2,I3,I4,I5,I6,I7,I8,I9,I90,I91,I92,I93,I94,I95,I96,I97,I98,I99글로벌 리얼V(100),V0,V1,V2,V3,V4,V5,V6,V7,V8,V9,V90,V91,V92,V93,V94,V95,V96,V97,V98,V99이것은 시스템에서 축의 이름을 정의하는 수단을 제공합니다(axisdef). 둘그러나 하나는 정수이고 하나는 실수인 100개의 요소 배열은 내부용입니다.#RESET 명령은 D 버퍼의 기본 내용을 복원합니다.
상태 변수 - 예는 즉각적인 보고를 하는 FPOS(피드백 위치)입니다.다음을 포함한 모터 상태를 나타내는 모터 및 MST(모터 상태)의 위치활성화 여부와 모션에 관여하는지 여부.>구성 변수 - 구성 변수의 값은 컨트롤러를특정 제어 개체. 허용 가능한 값을 지정하는 ACC(가속도)가 그 예입니다.모터의 가속도와 SLLIMIT(Software Left Limit)에 대한 하한을 지정합니다.운동영역 등
P65) TILL 명령은 지정된 표현식이 0이 아닌 값을 생성할 때까지 프로그램 실행을 지연합니다.  ex) until ^AST(0).#이동0축 동작이 완료될 때까지 기다립니다.
P70) START 2, Pstart ,   Pstart 라벨이 붙은 라인에 2번 버퍼를 실행한다
p70) ?2 2번 버퍼 상태를 조회한다
p70) Buffer 2: 192 lines, running iekn line 153  --> 쿼리(조회)에 대한 반응
p71) IF ^MST(0). --> 0축이 비활성화 된 경우에만 프로그램 종료
p71) STOP 3  --> 버퍼 3에서 실행된 프로그램을 종료   ( if STOPALL --> 모두 종료)
p72) pause 0 --> 0번 버퍼 종료
ENABLEON 버퍼 번호   --> 자동루틴 활성화  DISABLEON 버퍼 번호 --> 자동루틴 비활성화


=========================================모션 프로그래밍==============================
p74)ENABLE 0 --> 축 0 활성화  만약 (0,2) 라면 0축과 2축 둘다 활성화
      DISABLE 2,5011  --> 축 2를 비활성화 하고 비활성화 이유로 5011을 저장한다.
      DISABLE (0,1) --> 축0과 축1의 모터 비활성화
p75) COMMUT axis, [excitation_current,] [settle_time,] [slope_time][gantry_commut_delay]
  -->COMMUT 정류할 축,자동 정류중 사용되는 모터 전류 지정, 자동 정류 안정화 시간을 지정, 남은 전류가 0에서 원하는 값으로 상승하는 시간 지정(웬만하면 생략 가능), 지연시간 지정(Gantry mode에서만 지원)
p76) KILL axis_specification [,cause] --> 하나 이상의 모터가 2차 명령을 사용해 모션을 종료함, axis_specification은 단일 축(0,1)이거나 축으로 묶인 문자열 cause는 정수
p78) SET 축_VAR=expression --> SET 명령은 마스터 위치의 현재 값을 결정한다. 축_VAR = FPOS:피드백 위치, F2POS: 2차 피드백 위치, RPOS: 기준 위치, APOS: 축 기준 위치
     ex) SET FPOS(0) =0 --> 이 순간 모터의 위치 지점에 0축의 원점을 놓는다
          SET F2POS(0) = 0 --> 모터가 현재 위치한 지점에 0축이 두번째 피드백 지점을 원점으로 놓는다
p84) IMM motion_var = command --> 진행 모션과 대기중인 모션에도 영향을 미친다, motion_var = VEL:속도, ACC:가속도, DEC:감속도, JERK:jerk, KDEC:감속도를 줄인다
p85) PTP[/switch]axis_designation,target_point[,velocity] --> point to point 위치 설정, switch= 옵션으로 e: 다음명령 실행 전 모션 종료, v: 기본 속도 대신 지정된 속도 사용
       ex) PTP 0,1000 0축이 1000까지 모션 이동  PTP/e 2,1000 == PTP 2,1000 \ TILL ^AST(1). --> 모션이 1000까지 갈 때 까지 기다림
p88)  MPTP --> 모르겠음 
p99) JOG = 모터를 구동함에 있어서 본격적으로 움직이기 위해 준비운동처럼 조금씩 원하는 위치까지 이동시키는 모드
       JOG[/스위치] axis_designator [,direction][,velocity] --> /스위치=(w:모션생성하되 go 명령이 내려지기 전까지 시작금지) (v:기본속도 대신 명령에 지정된 속도를 사용), 
                        axis_designator = 축 이름, direction= +,-(방향) , velocity(속도)
       ex) JOG 0 --> 기본속도로 양의 방향으로 0축의 조그 동작 실행 , JOG/V 0,30 --> 기본 속도 무시하고 30속도로 조그 모션 생성 , JOG (0,1,4), -++ --> 0축은 음, 1축은 양, 4축은 양의 방향으로 조그 진행
p100) TRACK[/w] axis_designator --> 목표 위치가 다음과 같을 때 자동으로 이동을생성해 처리량을 향상시킴  -- 잘 모르겠음 다시 읽기 바람
         [/w] = go명령이 시작될 때 까지 기다린다, TRACK 0 --> 0축의 트랙 모션 생성
p103)분할 모션 Segmented Motion --> 연속 경로를 따라 축을 이동    S=F(T) --> S: 분할 된 경로에 따른 거리, F: 함수 독립, T: 시간 if F y(s) == XY 평면에서 경로 모양 만듬

p104) MESG[/switch] axis_group, final_point [, initial_start_point, initial_start_point][, projection matrix_designator]
        LINE[/switch] axis_group, fianl_point [,final_point, final_point]
        ARC1[/switch] axis_group, center_point, final_point, rotation_direction [,velocity]
        ARC2[/switch] axis_group, center_point, rotation_angle, rotation_direction [, velocity]
        STOPPER axis_group
        ENDS axis_group
       [/switch] 옵션 --> w: go명령이 나올 때까지 시작 금지, V:지정된 속도 사용, C: 세그먼트 시퀀스를 순환 배열로 사용(반복같은거?), S: 슬레이브 모션 - 리딩의 마스터 값에 따라 모션 진행, P:위치 고정, 마스터 값을 엄격히 준수, e,t
 
p105)  밑의 명령어들은 세그먼트 명령어들이다. 그래서 명령어 끝난 시점의 점을 기준을 시작으로 다음 명령어가 계속해서 움직이게 된다.
        MESG (0,1), 1000, 1000 --> MESG명령은 축 그룹과 초기 시작점을 지정한다.  0,1축 초기좌표 포인트는 1000,1000이다.
        ARC1 (0,1),1000,0,1000,-1000,-   --> 중심이 있는 호 세그먼트 추가(1000,0), 최종 포인트(1000,-1000), 시계 방향 회전       --> 따라서 ARC1은 중심좌표, 최종 점, 회전방향
   
        LINE (0,1), -1000, -1000 -->현재 지점부터 끝점(-1000,-1000)으로 라인을 그리는 세그먼트
        ARC2 (0,1), -1000,0,-3.141529  --> 중심이 있는 호 세그먼트 추가, (-1000,0) 및 회전 각도(파이 라디안)    --> 따라서 ARC2는 중심점 좌표, 회전각도(라디안) 필요
        ENDS (0,1) --> 세그먼트 시퀀스 종료
p107) projection command -- 잘 모르겠음
p110) STOPPER  --> 변곡점에서 속도 점프가 나는 것을 방지하는데 사용   ex) STOPPER(0,1)
p112) Corner Processing  --> 코너처리는 코너의 자동 감지 및 속도 계산이 포함되어 가속 및 저크 제한을 초과하지 않고 코너를 통과한다.
p121) XSEG... END --> ARC1,ARC2,LINE, END 명령을 한번에 통합해 사용 가능
p130) LINE --> 상세설명 참조
p136) IMM --> IMM명령어는 모션 진행 중 속도, 가속도, 감속도 및 저크의 새 값을 즉시 적용시키는 명령어, XSEG와 같이 사용
p152) Spline Motion 뭔지 잘 모르겠음  p153에 스플라인 이론에 대한 PVSPLINE 명령어 있음
p157) 개방루프 작동(토크제어)  DCOM축이름=n --> 축이름은 n프로 최대 토크로 설정
p162) Input and output
p163) 디지털 출력 할당: OUT만 출력 가능, 저전압=0, 고전압=1 ex) OUT0.1 = 1 --> 0.1 출력
p164) OUT0.1=V0 --> V0dl 0dlaus OUT0.1을 0으로 설정, 그렇지 않으면 1로 설정
p166) 5.1.6 자동 루틴 디지털 I/0 --> 
	ON IN0.0             --> 입력이 #0=0일때
	OUT 0.4 =1          --> 출력(OUT) #4를 1로 설정
	disp"Activates moter"
	RET                   --> 자동 루틴 종료
p166) 아날로그 입출력
p172) 컨트롤러 응답 에러 코드 설명
p234) PEG
p282) spiiPlus C 라이브러리 통신 (TCP/IP)
? 축이름 --> 축이름에 대한 축의 상태 터미널에 출력
