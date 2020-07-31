package com.spring.tourism.Controller;

import com.spring.tourism.Entity.*;
import com.spring.tourism.Repository.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.CookieValue;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;

import javax.annotation.Resource;
import java.util.*;

@Controller
@RequestMapping(path = "/travelController")
public class TravelController {
    @Resource
    private JdbcTemplate jdbcTemplate;

    private final TravelImageRepository travelImageRepository;

    private final UserTravelSaveRepository userTravelSaveRepository;

    private final TravelProductRepository travelProductRepository;

    @Autowired
    public TravelController(TravelImageRepository travelImageRepository,
                            UserTravelSaveRepository userTravelSaveRepository,
                            TravelProductRepository travelProductRepository) {
        this.travelImageRepository = travelImageRepository;
        this.userTravelSaveRepository = userTravelSaveRepository;
        this.travelProductRepository = travelProductRepository;
    }

    @GetMapping(path = "/travelDetail")
    public String travelDetail(Model model,
                               String travelId) {
        if (travelId == null || travelId.trim().length() == 0) {
            return "redirect:/travel";
        }

        try {
            TravelImages travelImages = new TravelImages();
            TravelProductEntity travelProductEntity =
                    travelProductRepository.getTravelProductEntityByTravelId(travelId);
            List<TravelImageEntity> travelImageEntityList =
                    travelImageRepository.getTravelImageEntitiesByTravelId(travelId);
            travelImages.setTravelProductEntity(travelProductEntity);
            travelImages.setTravelImageEntities(travelImageEntityList);

            model.addAttribute("travelImages", travelImages);
            return "travelDetail";
        } catch (Exception e) {
            return null;
        }
    }

    @GetMapping(path = "/travelSchedule")
    public String travelSchedule(Model model,
                                 String travelId,
                                 @CookieValue(value = "userId", defaultValue = "") String userId) {
        if (travelId == null || travelId.trim().length() == 0) {
            return "error";
        }

        try{
            TravelScheduleImpl travelSchedule =
                    new TravelScheduleImpl(jdbcTemplate);

            List<TravelStokeEntity> travelStokeEntityList =
                    travelSchedule.getTravelStokeByTravelId(travelId);
            travelStokeEntityList.remove(travelStokeEntityList.size() - 1);

            Map<Short, List<Map<Short, String>>> travelStokeMap = new HashMap<>();

            TravelProductEntity travelProductEntity =
                    travelProductRepository.getTravelProductEntityByTravelId(travelId);

            for (TravelStokeEntity travelStokeEntity: travelStokeEntityList) {
                Map<Short, String> stokeMap = new HashMap<>();
//                System.out.println(travelStokeEntity.toString());
                stokeMap.put(travelStokeEntity.getTravelCopyId(),
                        travelStokeEntity.getTravelStepDetail().replaceAll("<br>", "\n"));

                if (!travelStokeMap.containsKey(travelStokeEntity.getTravelStepId())) {
                    List<Map<Short, String>> mapList = new ArrayList<>();
                    mapList.add(stokeMap);

                    travelStokeMap.put(travelStokeEntity.getTravelStepId(), mapList);
                } else {
                    travelStokeMap.get(travelStokeEntity.getTravelStepId()).add(stokeMap);
                }
            }

            TreeMap<Short, List<Map<Short, String>>> sorted = new TreeMap<>(travelStokeMap);

            UserTravelSaveEntity userTravelSaveEntity =
                    userTravelSaveRepository.getUserTravelSaveEntitiesByUserIdAndTravelId(userId, travelId);

            if (userTravelSaveEntity != null) {
                model.addAttribute("isSave", true);
            } else {
                model.addAttribute("isSave", false);
            }

            model.addAttribute("travelStoke", sorted);
            model.addAttribute("travelProduct", travelProductEntity);
            return "travelSchedule";
        } catch (Exception e) {
            return "error";
        }
    }

    @GetMapping(path = "/travelFindBySearch")
    public String travelFind(Model model,
                             String searchInput) {
        try {

            if (searchInput == null || searchInput.trim().length() == 0) {
                return "error";
            }

            TravelSearchImpl travelSearch = new TravelSearchImpl(jdbcTemplate);
            model.addAttribute("searchResult", travelSearch.
                    getTravelSearchResultByKeyWord(searchInput));

            return "travelFind";
        } catch (Exception e) {
            return "error";
        }
    }

    @GetMapping(path = "/travelFindByNav")
    public String travelNavFind(Model model,
                                String searchInput,
                                String placeholder) {
        try {
            if (searchInput == null || searchInput.trim().length() == 0) {
                return "error";
            }

            int placeholderNum;

            if (placeholder == null || placeholder.trim().length() == 0) {
                placeholderNum = 0;
            } else {
                placeholderNum = Integer.parseInt(placeholder);
            }

            TravelSearchImpl travelSearch = new TravelSearchImpl(jdbcTemplate);

            if (placeholderNum <= 2) {
                model.addAttribute("searchResult", travelSearch.
                        getTravelSearchResultByKeyWord(searchInput));
            } else {
                if (placeholderNum == 3)
                    model.addAttribute("searchResult", travelSearch.getTravelSearchOrderByVisitNum());
                else if (placeholderNum == 4)
                    model.addAttribute("searchResult", travelSearch.getTravelSearchOrderByScore());
                else
                    return "error";
            }

            model.addAttribute("placeholder", placeholderNum);
            return "travelFindByNav";
        } catch (Exception e) {
            return "error";
        }
    }
}
